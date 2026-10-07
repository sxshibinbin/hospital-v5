"""AI 生成合成内容标识元数据（GB 45438-2025 六要素）。"""

import os
import re
import time
import uuid
from typing import Optional, TypedDict


class AiLabelMeta(TypedDict):
    aiGenerated: bool
    serviceProviderCode: str
    contentId: str
    generateTimestamp: int
    packageName: str
    reserved: str


SERVICE_PROVIDER_CODE = os.getenv(
    "AI_SERVICE_PROVIDER_CODE",
    "001191149900MA0LA3QG5T20001",
).strip() or "001191149900MA0LA3QG5T20001"
APP_PACKAGE_NAME = os.getenv("AI_APP_PACKAGE_NAME", "com.sstkjgf.app").strip() or "com.sstkjgf.app"
_CONTENT_ID_PATTERN = re.compile(r"^[0-9a-f]{32}$")


def new_content_id() -> str:
    """生成本次 AI 内容的 UUID4 hex 编号。"""
    return uuid.uuid4().hex


def _valid_content_id(value: object) -> Optional[str]:
    if not isinstance(value, str):
        return None
    normalized = value.strip().lower()
    return normalized if _CONTENT_ID_PATTERN.fullmatch(normalized) else None


def _valid_timestamp(value: object) -> Optional[int]:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        return None
    return value


def build_ai_label_meta(
    content_id: Optional[str] = None,
    generate_timestamp: Optional[int] = None,
) -> AiLabelMeta:
    """构建完整六要素元数据。

    contentId / generateTimestamp 允许沿链路复用；服务端始终负责其余字段，
    对客户端传入的编号和时间戳做格式校验，异常值自动重新生成。
    """
    return AiLabelMeta(
        aiGenerated=True,
        serviceProviderCode=SERVICE_PROVIDER_CODE,
        contentId=_valid_content_id(content_id) or new_content_id(),
        generateTimestamp=_valid_timestamp(generate_timestamp) or int(time.time() * 1000),
        packageName=APP_PACKAGE_NAME,
        reserved="",
    )
