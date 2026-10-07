from datetime import datetime
import json
import re
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel
from typing import List, Literal, Optional

from database import get_db
from dependencies import get_current_user
from models import ChatSession, User
from ai_label import build_ai_label_meta

import pytz

def get_beijing_time():
    return datetime.now(pytz.timezone('Asia/Shanghai')).replace(tzinfo=None)

router = APIRouter(prefix="/api/chat-sessions", tags=["chat-sessions"])

MAX_SESSION_TITLE_LENGTH = 36
CARD_BLOCK_PATTERN = re.compile(r"\[CARD\][\s\S]*?\[/CARD\]", re.MULTILINE)


class ChatSessionMessagePayload(BaseModel):
    id: str
    role: Literal["user", "ai"]
    content: str
    reasoning: Optional[str] = None
    status: Literal["local", "loading", "updating", "success", "error"] = "success"
    contextFileIds: List[str] = []
    attachments: List["ChatSessionAttachmentPayload"] = []
    aiLabelMeta: Optional[dict] = None


class ChatSessionAttachmentPayload(BaseModel):
    fileId: str
    name: str
    contentType: Optional[str] = None
    size: int = 0


class ChatSessionUpsertRequest(BaseModel):
    session_id: Optional[int] = None
    mode: Literal["normal", "medical"]
    messages: List[ChatSessionMessagePayload]


class ChatSessionSummaryResponse(BaseModel):
    id: int
    title: str
    mode: Literal["normal", "medical"]
    last_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class ChatSessionDetailResponse(ChatSessionSummaryResponse):
    messages: List[ChatSessionMessagePayload]


def normalize_text(value: Optional[str]) -> str:
    if not isinstance(value, str):
        return ""

    return value.strip()


def strip_card_payload(content: str) -> str:
    return CARD_BLOCK_PATTERN.sub("", content).strip()


def build_session_title(messages: List[ChatSessionMessagePayload]) -> str:
    first_user_message = next((item for item in messages if item.role == "user"), None)
    if not first_user_message:
        return "新的健康咨询"

    cleaned_content = strip_card_payload(first_user_message.content)
    cleaned_content = re.sub(r"\s+", " ", cleaned_content).strip()
    if not cleaned_content:
        return "新的健康咨询"

    return cleaned_content[:MAX_SESSION_TITLE_LENGTH]


def build_last_message(messages: List[ChatSessionMessagePayload]) -> Optional[str]:
    if not messages:
        return None

    last_message = strip_card_payload(messages[-1].content)
    if not last_message:
        return None

    compact_message = re.sub(r"\s+", " ", last_message).strip()
    return compact_message[:80]


def serialize_session_summary(session: ChatSession) -> ChatSessionSummaryResponse:
    messages = parse_session_messages(session.messages_json)
    return ChatSessionSummaryResponse(
        id=session.id,
        title=session.title,
        mode=session.mode,
        last_message=build_last_message(messages),
        created_at=session.created_at,
        updated_at=session.updated_at,
    )


def parse_session_messages(raw_messages: str) -> List[ChatSessionMessagePayload]:
    try:
        parsed_messages = json.loads(raw_messages)
    except json.JSONDecodeError:
        parsed_messages = []

    if not isinstance(parsed_messages, list):
        return []

    messages: List[ChatSessionMessagePayload] = []
    for item in parsed_messages:
        if not isinstance(item, dict):
            continue
        try:
            message = ChatSessionMessagePayload.model_validate(item)
        except Exception:
            continue
        if normalize_text(message.content):
            messages.append(message)

    return messages


def _merge_ai_label(meta: Optional[dict]) -> dict:
    """保留合法链路编号/时间，其余六要素由服务端权威生成。"""
    incoming = meta if isinstance(meta, dict) else {}
    content_id = incoming.get("contentId")
    timestamp = incoming.get("generateTimestamp")
    return build_ai_label_meta(
        content_id=content_id if isinstance(content_id, str) else None,
        generate_timestamp=timestamp if isinstance(timestamp, int) and not isinstance(timestamp, bool) else None,
    )


@router.get("", response_model=List[ChatSessionSummaryResponse])
async def list_chat_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = (
        select(ChatSession)
        .where(ChatSession.user_id == current_user.id)
        .order_by(desc(ChatSession.updated_at), desc(ChatSession.id))
    )
    result = await db.execute(stmt)
    sessions = result.scalars().all()
    return [serialize_session_summary(session) for session in sessions]


@router.get("/{session_id}", response_model=ChatSessionDetailResponse)
async def get_chat_session(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(ChatSession).where(ChatSession.id == session_id, ChatSession.user_id == current_user.id)
    result = await db.execute(stmt)
    session = result.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="未找到对应的对话历史")

    messages = parse_session_messages(session.messages_json)
    summary = serialize_session_summary(session)
    return ChatSessionDetailResponse(
        **summary.model_dump(),
        messages=messages,
    )


@router.post("", response_model=ChatSessionSummaryResponse)
async def upsert_chat_session(
    payload: ChatSessionUpsertRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    valid_messages = [item for item in payload.messages if normalize_text(item.content)]
    if not valid_messages:
        raise HTTPException(status_code=400, detail="对话历史不能为空")

    session: Optional[ChatSession] = None
    if payload.session_id is not None:
        stmt = select(ChatSession).where(ChatSession.id == payload.session_id, ChatSession.user_id == current_user.id)
        result = await db.execute(stmt)
        session = result.scalars().first()
        if not session:
            raise HTTPException(status_code=404, detail="未找到对应的对话会话")

    if session is None:
        session = ChatSession(
            user_id=current_user.id,
            title=build_session_title(valid_messages),
            mode=payload.mode,
            messages_json="[]",
        )
        db.add(session)

    for item in valid_messages:
        if item.role == "ai":
            item.aiLabelMeta = _merge_ai_label(item.aiLabelMeta)

    session.title = build_session_title(valid_messages)
    session.mode = payload.mode
    session.messages_json = json.dumps([item.model_dump() for item in valid_messages], ensure_ascii=False)
    session.updated_at = get_beijing_time()

    await db.commit()
    await db.refresh(session)

    return serialize_session_summary(session)


@router.get("/{session_id}/messages")
async def get_session_messages(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """获取会话的格式化消息列表，用于恢复对话上下文。"""
    stmt = select(ChatSession).where(
        ChatSession.id == session_id, ChatSession.user_id == current_user.id
    )
    result = await db.execute(stmt)
    session = result.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="未找到对应的对话会话")

    messages = parse_session_messages(session.messages_json)
    return {
        "session_id": session.id,
        "title": session.title,
        "mode": session.mode,
        "messages": [m.model_dump() for m in messages],
    }


@router.delete("/{session_id}")
async def delete_chat_session(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(ChatSession).where(ChatSession.id == session_id, ChatSession.user_id == current_user.id)
    result = await db.execute(stmt)
    session = result.scalars().first()
    if not session:
        raise HTTPException(status_code=404, detail="未找到对应的对话会话")

    await db.delete(session)
    await db.commit()

    return {"success": True}
