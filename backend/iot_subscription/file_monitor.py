"""
IoT 推送数据文件监听模块

扫描轮转日志目录，发现已关闭的日志文件后自动解析入库。
应用启动后长期运行，通过 (文件路径, 字节偏移量) 精确续读，
通过数据库签名去重避免重复写入。

目录结构：
  root_dir/YYYYMMDD/HH/upload_YYYYMMDD_HH_001.log
"""
import asyncio
import json
import re
import time
from pathlib import Path
from typing import Optional
from loguru import logger

from iot_subscription.database import (
    IOT_FILE_BATCH_SECONDS,
    IOT_FILE_BATCH_SIZE,
    get_connection,
    process_events_batch,
)

# 与 router.py 中的 log_writer 保持一致的根目录
LOG_ROOT = Path(__file__).parent.parent / "logs" / "app_upload"
POLL_INTERVAL = 2  # 秒
LINE_PATTERN = re.compile(r"^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d{1,6})?)\] \[\w+\] (.+)$")
FILE_MATURITY_SECONDS = 5  # 文件至少 5 秒未修改才视为已关闭（平衡实时性与安全性）

# 监听状态
_state = {
    "file_path": None,   # 当前正在读取的文件路径
    "offset": 0,         # 当前文件字节偏移量
    "initialized": False, # 是否已初始化（首次启动跳过已有文件）
}


# ========== 数据过滤 ==========

def _is_device_event(data: dict) -> bool:
    return "dataType" in data and "imei" in data and "signTime" in data


# ========== 目录扫描 ==========

def _scan_files() -> list[Path]:
    """
    扫描所有已关闭的日志文件，按目录+文件名排序返回。
    只返回 mtime 早于 FILE_MATURITY_SECONDS 的文件（确保写服务已彻底关闭）。
    """
    if not LOG_ROOT.exists():
        return []

    now = time.time()
    maturity_threshold = now - FILE_MATURITY_SECONDS

    files = []
    for date_dir in sorted(LOG_ROOT.glob("[0-9]" * 8)):
        if not date_dir.is_dir():
            continue
        for hour_dir in sorted(date_dir.glob("[0-9]" * 2)):
            if not hour_dir.is_dir():
                continue
            for f in sorted(hour_dir.glob("upload_*.log")):
                try:
                    mtime = f.stat().st_mtime
                    if mtime >= maturity_threshold:
                        # 文件仍在被写入，跳过
                        continue
                except OSError:
                    continue
                files.append(f)

    return files


def _checkpoint_path(file_path: Path) -> str:
    """Normalize the path used as the checkpoint primary key."""
    return str(file_path.resolve())


def _checkpoint_status(offset: int, file_size: int) -> str:
    return "completed" if offset >= file_size else "processing"


def _get_checkpoint(file_path: Path) -> tuple[int, bool]:
    """Return (offset_bytes, exists) for a log file checkpoint."""
    checkpoint_path = _checkpoint_path(file_path)
    file_size = file_path.stat().st_size

    with get_connection() as conn:
        row = conn.execute("""
            SELECT offset_bytes
            FROM iot_file_offsets
            WHERE file_path = %s
        """, (checkpoint_path,)).fetchone()

    if row is None:
        return 0, False

    offset = int(row[0] or 0)
    if offset > file_size:
        logger.warning(
            f"文件监听 checkpoint 超过文件大小，重置: file={file_path.name}, "
            f"offset={offset}, file_size={file_size}"
        )
        _save_checkpoint(file_path, 0, file_size, _checkpoint_status(0, file_size))
        return 0, True

    return offset, True


def _save_checkpoint(file_path: Path, offset: int, file_size: int, status: str) -> None:
    """Persist the last processed byte offset for a log file."""
    checkpoint_path = _checkpoint_path(file_path)
    offset = max(0, min(int(offset), int(file_size)))

    with get_connection() as conn:
        conn.execute("""
            INSERT INTO iot_file_offsets
                (file_path, offset_bytes, file_size, status, updated_at, completed_at)
            VALUES
                (%s, %s, %s, %s, CURRENT_TIMESTAMP,
                 CASE WHEN %s = 'completed' THEN CURRENT_TIMESTAMP ELSE NULL END)
            ON CONFLICT (file_path) DO UPDATE SET
                offset_bytes = EXCLUDED.offset_bytes,
                file_size = EXCLUDED.file_size,
                status = EXCLUDED.status,
                updated_at = CURRENT_TIMESTAMP,
                completed_at = CASE
                    WHEN EXCLUDED.status = 'completed' THEN CURRENT_TIMESTAMP
                    ELSE NULL
                END
        """, (checkpoint_path, offset, file_size, status, status))


def _find_resume_point(files: list[Path]) -> tuple[Optional[Path], int]:
    """Find the first mature file whose checkpoint has not reached EOF."""
    for file_path in files:
        file_size = file_path.stat().st_size
        offset, _ = _get_checkpoint(file_path)
        if offset < file_size:
            return file_path, offset

    if files:
        last = files[-1]
        return last, last.stat().st_size

    return None, 0


def _init_state():
    """首次启动：根据 iot_file_offsets 找到可续读位置。"""
    files = _scan_files()
    file_path, offset = _find_resume_point(files)
    if file_path is not None:
        _state["file_path"] = str(file_path)
        _state["offset"] = offset
        logger.info(
            f"文件监听器初始化: 发现 {len(files)} 个已有文件，"
            f"从 {file_path.name} offset={offset} 开始"
        )
    else:
        logger.info("文件监听器初始化: 无已有文件，从头开始监听")
    _state["initialized"] = True


# ========== 处理逻辑 ==========

async def _process_file(file_path: Path, offset: int) -> tuple[int, int]:
    """
    处理单个文件，从 offset 开始按批读取。
    返回 (新 offset, 本文件新入库条数)。
    """
    file_size = file_path.stat().st_size
    offset = max(0, min(int(offset), int(file_size)))
    if file_size <= offset:
        _save_checkpoint(file_path, offset, file_size, "completed")
        return offset, 0

    inserted = 0
    current_offset = offset
    started_at = time.monotonic()

    with open(file_path, "rb") as f:
        f.seek(offset)
        while f.tell() < file_size:
            batch_start_offset = f.tell()
            batch: list[dict] = []

            while f.tell() < file_size and len(batch) < IOT_FILE_BATCH_SIZE:
                line_start = f.tell()
                raw_line = f.readline()
                if not raw_line:
                    break
                line_end = f.tell()
                current_offset = line_end
                line = raw_line.decode("utf-8", errors="replace").strip()

                if not line:
                    continue

                m = LINE_PATTERN.match(line)
                if not m:
                    logger.warning(
                        f"文件监听跳过无法解析的行: file={file_path.name}, offset={line_start}"
                    )
                    continue

                try:
                    data = json.loads(m.group(2))
                except json.JSONDecodeError:
                    logger.warning(
                        f"文件监听跳过非法 JSON 行: file={file_path.name}, offset={line_start}"
                    )
                    continue

                if not _is_device_event(data):
                    continue

                perf = data.get("_perf")
                if isinstance(perf, dict):
                    perf.setdefault("file_path", str(file_path.resolve()))
                    perf.setdefault("file_offset_bytes", line_start)
                    perf["file_read_ms"] = round(time.time() * 1000, 3)

                batch.append(data)

                if time.monotonic() - started_at >= IOT_FILE_BATCH_SECONDS:
                    break

            if not batch:
                _save_checkpoint(
                    file_path,
                    current_offset,
                    file_size,
                    _checkpoint_status(current_offset, file_size),
                )
                if time.monotonic() - started_at >= IOT_FILE_BATCH_SECONDS:
                    break
                continue

            try:
                def _write_batch():
                    with get_connection() as conn:
                        return process_events_batch(conn, batch)

                batch_inserted = await asyncio.to_thread(_write_batch)
                inserted += batch_inserted
                logger.info(
                    f"文件监听批量入库: inserted={batch_inserted}, "
                    f"batch_size={len(batch)}, file={file_path.name}, offset={current_offset}"
                )
            except Exception as e:
                _save_checkpoint(file_path, batch_start_offset, file_size, "error")
                logger.error(
                    f"文件监听批量处理异常，保留 checkpoint 等待重试: "
                    f"file={file_path.name}, offset={batch_start_offset}, error={e}"
                )
                return batch_start_offset, inserted

            _save_checkpoint(
                file_path,
                current_offset,
                file_size,
                _checkpoint_status(current_offset, file_size),
            )

            if time.monotonic() - started_at >= IOT_FILE_BATCH_SECONDS:
                break

    return current_offset, inserted


async def _poll_once():
    """单次扫描：找到待处理文件并处理"""
    files = _scan_files()
    if not files:
        return

    total_inserted = 0

    for f in files:
        file_size = f.stat().st_size
        offset, has_checkpoint = _get_checkpoint(f)

        if offset >= file_size:
            if not has_checkpoint:
                _save_checkpoint(f, file_size, file_size, "completed")
            continue

        new_offset, inserted = await _process_file(f, offset)
        total_inserted += inserted
        _state["file_path"] = str(f)
        _state["offset"] = new_offset

        # 当前文件未处理完成，保留位置等待下一轮重试。
        if new_offset < file_size:
            break

    if total_inserted > 0:
        logger.info(f"本轮共处理 {total_inserted} 条新数据")


async def file_monitor_loop():
    """文件监听主循环，作为后台任务长期运行"""
    # 等待根目录创建（首次可能不存在）
    while not LOG_ROOT.exists():
        await asyncio.sleep(POLL_INTERVAL)

    _init_state()
    logger.info(
        f"文件监听器启动，监控: {LOG_ROOT}，间隔: {POLL_INTERVAL}s, "
        f"batch_size={IOT_FILE_BATCH_SIZE}, batch_seconds={IOT_FILE_BATCH_SECONDS}"
    )

    while True:
        try:
            await _poll_once()
        except Exception as e:
            logger.error(f"文件监听循环异常: {e}")
        await asyncio.sleep(POLL_INTERVAL)
