"""
IoT 推送数据轮转日志写入器

按"时间（小时）+ 大小"双条件滚动写入：
- 目录结构: root_dir/dt=YYYYMMDD/hour=HH/
- 文件命名: upload_YYYYMMDD_HH_001.log
- 写入时: .tmp 后缀，滚动后去掉 .tmp
- 线程安全，写入走 OS Page Cache（不逐行 flush）
"""
import os
import re
import json
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Any
from loguru import logger


class RotatingLogWriter:
    """按小时分区 + 大小滚动的日志写入器"""

    def __init__(self, root_dir: str | Path, max_file_size: int = 1 * 1024 * 1024 * 1024):
        """
        Args:
            root_dir: 日志根目录
            max_file_size: 单文件最大字节数，默认 1GB
        """
        self.root_dir = Path(root_dir)
        self.max_file_size = max_file_size

        self._lock = threading.Lock()
        self._fh = None           # 当前文件句柄
        self._current_path = None # 当前 .tmp 文件路径
        self._current_hour = None # 当前小时键 "YYYYMMDD_HH"
        self._seq = 0             # 当前序号
        self._current_size = 0    # 当前文件已写字节数

    def write(self, line: str) -> None:
        """写入一行数据（线程安全）"""
        line_bytes = (line.rstrip("\n") + "\n").encode("utf-8")
        with self._lock:
            self._ensure_writer()
            self._fh.write(line_bytes)
            self._fh.flush()  # 立即刷到 OS 缓冲区，确保可见
            self._current_size += len(line_bytes)

    def write_json_record(self, tag: str, data: dict[str, Any]) -> None:
        """写入 IoT JSON 行，并为压测 payload 补充文件落盘时间。"""
        with self._lock:
            self._ensure_writer()

            perf = data.get("_perf")
            if isinstance(perf, dict):
                perf["file_write_ms"] = round(time.time() * 1000, 3)
                perf["file_path"] = str(self._current_path)
                perf["file_offset_bytes"] = self._current_size

            now = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")
            line = f"[{now}] [{tag}] {json.dumps(data, ensure_ascii=False)}"
            line_bytes = (line.rstrip("\n") + "\n").encode("utf-8")
            self._fh.write(line_bytes)
            self._fh.flush()  # 立即刷到 OS 缓冲区，确保可见
            self._current_size += len(line_bytes)

    def close(self) -> None:
        """关闭当前文件，.tmp 重命名为正式文件"""
        with self._lock:
            self._finalize_current()

    # ========== 内部方法 ==========

    def _ensure_writer(self):
        """检查是否需要创建/滚动文件，必须在锁内调用"""
        now = datetime.now()
        hour_key = now.strftime("%Y%m%d_%H")

        if self._fh is None:
            # 首次启动
            self._current_hour = hour_key
            self._seq = self._recover_seq(hour_key)
            self._open_new_file()
            return

        # 检查时间滚动（整点）
        if hour_key != self._current_hour:
            self._finalize_current()
            self._current_hour = hour_key
            self._seq = 1
            self._open_new_file()
            return

        # 检查大小滚动
        if self._current_size >= self.max_file_size:
            self._finalize_current()
            self._seq += 1
            self._open_new_file()

    def _open_new_file(self):
        """打开新的 .tmp 文件，必须在锁内调用"""
        date_part = self._current_hour[:8]   # YYYYMMDD
        hour_part = self._current_hour[9:]   # HH
        dir_path = self.root_dir / date_part / hour_part
        dir_path.mkdir(parents=True, exist_ok=True)

        filename = f"upload_{self._current_hour}_{self._seq:03d}.log"
        self._current_path = dir_path / filename
        self._fh = open(self._current_path, "ab")
        self._current_size = self._current_path.stat().st_size if self._current_path.exists() else 0
        logger.debug(f"轮转写入器: 打开新文件 {self._current_path}")

    def _finalize_current(self):
        """关闭当前文件，必须在锁内调用。空文件直接删除。"""
        if self._fh is not None:
            try:
                self._fh.flush()
                os.fsync(self._fh.fileno())
            except Exception:
                pass

            path = self._current_path
            size = self._current_size
            self._fh.close()
            self._fh = None

            if size == 0 and path.exists():
                path.unlink()
                logger.debug(f"轮转写入器: 删除空文件 {path.name}")
            else:
                logger.debug(f"轮转写入器: 关闭文件 {path.name}")

            self._current_path = None
            self._current_size = 0

    def _recover_seq(self, hour_key: str) -> int:
        """启动时扫描当前小时目录，恢复序号（避免覆盖已有文件）"""
        date_part = hour_key[:8]
        hour_part = hour_key[9:]
        dir_path = self.root_dir / date_part / hour_part

        if not dir_path.exists():
            return 1

        pattern = re.compile(rf"upload_{hour_key}_(\d{{3}})\.log(?:\.tmp)?$")
        max_seq = 0
        for f in dir_path.iterdir():
            m = pattern.match(f.name)
            if m:
                max_seq = max(max_seq, int(m.group(1)))

        return max_seq + 1 if max_seq > 0 else 1
