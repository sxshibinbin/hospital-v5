import os
import sys
from pathlib import Path
from loguru import logger


def _get_log_level() -> str:
    return os.getenv("LOG_LEVEL", "INFO").upper()


def _is_json_format() -> bool:
    return os.getenv("LOG_FORMAT", "").strip().lower() == "json"


def setup_logger():
    logger.remove()

    log_level = _get_log_level()
    use_json = _is_json_format()

    if use_json:
        # 生产 JSON 结构化日志格式
        console_format = (
            '{"time":"{time:YYYY-MM-DD HH:mm:ss.SSS}","level":"{level}","name":"{name}",'
            '"function":"{function}","line":{line},"message":"{message}"}'
        )
        file_format = console_format
    else:
        console_format = (
            "<green>{time:YYYY-MM-DD HH:mm:ss.SSS}</green> | "
            "<level>{level: <8}</level> | "
            "<cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - "
            "<level>{message}</level>"
        )
        file_format = (
            "{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | "
            "{name}:{function}:{line} - {message}"
        )

    # 控制台输出
    logger.add(
        sys.stdout,
        level=log_level,
        format=console_format,
        enqueue=True,
    )

    # 文件输出
    log_dir = Path(os.getcwd()) / "logs"
    log_dir.mkdir(exist_ok=True)

    # 全量日志文件
    log_file_path = log_dir / "hospital_backend_{time:YYYY-MM-DD}.log"
    logger.add(
        log_file_path,
        rotation="00:00",
        retention="30 days",
        compression="zip",
        level=log_level,
        format=file_format,
        enqueue=True,
    )

    # 错误日志独立文件
    error_log_path = log_dir / "hospital_error_{time:YYYY-MM-DD}.log"
    logger.add(
        error_log_path,
        rotation="00:00",
        retention="90 days",
        compression="zip",
        level="ERROR",
        format=file_format,
        enqueue=True,
    )
