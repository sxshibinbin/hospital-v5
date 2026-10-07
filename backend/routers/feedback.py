from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import desc, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import get_current_admin, get_current_user
from models import AiFeedback, ChatSession, User

router = APIRouter(prefix="/api/feedback", tags=["feedback"])


class FeedbackCreate(BaseModel):
    content: str = Field(min_length=1, max_length=5000)
    question: str = Field(default="", max_length=20000)
    ai_response: str = Field(min_length=1, max_length=50000)
    session_id: Optional[int] = None
    message_id: Optional[str] = Field(default=None, max_length=120)


def serialize_feedback(item: AiFeedback, user: User | None = None) -> dict:
    return {
        "id": item.id,
        "user_id": item.user_id,
        "feedback_user": (user.display_name if user and user.display_name else (user.phone if user else "")),
        "session_id": item.session_id,
        "message_id": item.message_id,
        "question": item.question or "未识别问题",
        "ai_response": item.ai_response,
        "content": item.content,
        "created_at": item.created_at.isoformat() if item.created_at else None,
    }


@router.post("")
async def create_feedback(
    payload: FeedbackCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if payload.session_id is not None:
        session = await db.scalar(select(ChatSession).where(ChatSession.id == payload.session_id, ChatSession.user_id == current_user.id))
        if session is None:
            raise HTTPException(status_code=404, detail="会话不存在")
    item = AiFeedback(user_id=current_user.id, **payload.model_dump())
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return serialize_feedback(item, current_user)


@router.get("/admin")
async def list_feedback(
    keyword: Optional[str] = Query(default=None, max_length=200),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(get_current_admin),
):
    stmt = select(AiFeedback, User).join(User, User.id == AiFeedback.user_id)
    if keyword and keyword.strip():
        term = f"%{keyword.strip()}%"
        stmt = stmt.where(or_(AiFeedback.content.ilike(term), AiFeedback.question.ilike(term), AiFeedback.ai_response.ilike(term), User.phone.ilike(term), User.display_name.ilike(term)))
    count_stmt = select(func.count(AiFeedback.id)).join(User, User.id == AiFeedback.user_id)
    if keyword and keyword.strip():
        term = f"%{keyword.strip()}%"
        count_stmt = count_stmt.where(or_(AiFeedback.content.ilike(term), AiFeedback.question.ilike(term), AiFeedback.ai_response.ilike(term), User.phone.ilike(term), User.display_name.ilike(term)))
    total = int((await db.scalar(count_stmt)) or 0)
    rows = (await db.execute(stmt.order_by(desc(AiFeedback.created_at)).offset((page - 1) * page_size).limit(page_size))).all()
    return {"items": [serialize_feedback(item, user) for item, user in rows], "total": total, "page": page, "page_size": page_size}
