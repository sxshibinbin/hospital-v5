import json
from datetime import datetime

from fastapi import APIRouter, Body, Depends, HTTPException, Request
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import and_, desc, func, or_, text
from models import HighFreqQuestion, User, ChatSession, ConsultationRecord, PatientProfile, AuditLog, SystemConfig, Agreement
from routers.chat_sessions import ChatSessionSummaryResponse, ChatSessionDetailResponse, serialize_session_summary, parse_session_messages
from database import get_db
from db_encryption import phone_lookup_hash
from dependencies import get_current_admin
from operation_log_service import log_operation_safe
from security import get_password_hash, validate_password_strength
from cache import cache_invalidate
from pydantic import BaseModel
from typing import Any, List, Optional

router = APIRouter(prefix="/api/admin", tags=["admin"])


async def log_audit_action(
    *,
    current_admin: User,
    action: str,
    target_id: Optional[str] = None,
    details: Optional[str] = None,
    request: Request | None = None,
    module: str = "admin",
    result: str = "success",
    target_type: Optional[str] = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    await log_operation_safe(
        request=request,
        actor_user=current_admin,
        actor_type="admin",
        terminal="admin_web",
        module=module,
        action=action,
        result=result,
        target_type=target_type,
        target_id=target_id,
        details=details,
        metadata=metadata,
    )

class QuestionBase(BaseModel):
    question: str
    answer_template: str
    category: Optional[str] = None
    is_top: bool = False
    status: str = "draft"
    sort_weight: int = 0

class QuestionCreate(QuestionBase):
    pass

class QuestionResponse(QuestionBase):
    id: int
    click_count: int
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True

def _serialize_question(db_question: HighFreqQuestion) -> QuestionResponse:
    return QuestionResponse(
        id=db_question.id,
        question=db_question.question,
        answer_template=db_question.answer_template,
        category=db_question.category,
        is_top=db_question.is_top,
        status=db_question.status,
        sort_weight=db_question.sort_weight,
        click_count=db_question.click_count,
        created_at=db_question.created_at.isoformat(),
        updated_at=db_question.updated_at.isoformat() if db_question.updated_at else db_question.created_at.isoformat(),
    )

@router.get("/dashboard/stats")
async def get_dashboard_stats(db: AsyncSession = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    total_users = await db.scalar(select(func.count(User.id)))
    total_sessions = await db.scalar(select(func.count(ChatSession.id)))
    total_consultations = await db.scalar(select(func.count(ConsultationRecord.id)))
    total_questions = await db.scalar(select(func.count(HighFreqQuestion.id)))
    
    recent_users_result = await db.execute(select(User).order_by(desc(User.created_at)).limit(5))
    recent_users = recent_users_result.scalars().all()
    
    recent_consultations_result = await db.execute(select(ConsultationRecord).order_by(desc(ConsultationRecord.created_at)).limit(5))
    recent_consultations = recent_consultations_result.scalars().all()

    return {
        "total_users": total_users or 0,
        "total_sessions": total_sessions or 0,
        "total_consultations": total_consultations or 0,
        "total_questions": total_questions or 0,
        "recent_users": [
            {
                "id": u.id,
                "phone": u.phone,
                "display_name": u.display_name or "未设置",
                "created_at": u.created_at.isoformat()
            } for u in recent_users
        ],
        "recent_consultations": [
            {
                "id": c.id,
                "department": c.department or "未知科室",
                "created_at": c.created_at.isoformat()
            } for c in recent_consultations
        ]
    }

class UserResponse(BaseModel):
    id: int
    phone: str
    display_name: str
    is_admin: bool
    is_active: bool
    is_deactivated: bool = False
    created_at: str
    profile_count: int
    session_count: int

@router.get("/users", response_model=List[UserResponse])
async def get_users(db: AsyncSession = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    stmt = select(
        User,
        func.count(PatientProfile.id.distinct()).label("profile_count"),
        func.count(ChatSession.id.distinct()).label("session_count")
    ).outerjoin(PatientProfile, User.id == PatientProfile.user_id) \
     .outerjoin(ChatSession, User.id == ChatSession.user_id) \
     .group_by(User.id) \
     .order_by(desc(User.created_at))
     
    result = await db.execute(stmt)
    rows = result.all()
    
    return [
        UserResponse(
            id=row.User.id,
            phone=row.User.phone,
            display_name=row.User.display_name or f"用户{row.User.phone[-4:]}",
            is_admin=row.User.is_admin,
            is_active=row.User.is_active,
            is_deactivated=row.User.deactivated_at is not None,
            created_at=row.User.created_at.isoformat(),
            profile_count=row.profile_count,
            session_count=row.session_count
        ) for row in rows
    ]

class UserStatusUpdate(BaseModel):
    is_active: bool

@router.put("/users/{user_id}/status")
async def update_user_status(
    request: Request,
    user_id: int,
    status_data: UserStatusUpdate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    if user.is_admin and not status_data.is_active:
        raise HTTPException(status_code=403, detail="Cannot disable admin user")

    # 已注销账号永久失效，不允许解封。
    if user.deactivated_at is not None:
        raise HTTPException(status_code=403, detail="该账号已注销，不可解封")

    user.is_active = status_data.is_active
    await db.commit()

    action_text = "解封" if status_data.is_active else "封禁"
    target_user_label = user.display_name or _mask_phone(user.phone) or str(user.id)
    await log_audit_action(
        current_admin=current_admin,
        request=request,
        action="update_user_status",
        target_id=str(user.id),
        target_type="user",
        details=f"{action_text}了用户 {target_user_label}",
    )
    
    return {"message": "User status updated successfully", "is_active": user.is_active}

@router.get("/users/{user_id}/chat-sessions", response_model=List[ChatSessionSummaryResponse])
async def get_user_chat_sessions(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin)
):
    # Verify user exists
    user_result = await db.execute(select(User).where(User.id == user_id))
    user = user_result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    stmt = (
        select(ChatSession)
        .where(ChatSession.user_id == user_id)
        .order_by(desc(ChatSession.updated_at), desc(ChatSession.id))
    )
    result = await db.execute(stmt)
    sessions = result.scalars().all()
    return [serialize_session_summary(session) for session in sessions]

@router.get("/chat-sessions/{session_id}", response_model=ChatSessionDetailResponse)
async def get_admin_chat_session(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin)
):
    stmt = select(ChatSession).where(ChatSession.id == session_id)
    result = await db.execute(stmt)
    session = result.scalars().first()
    
    if not session:
        raise HTTPException(status_code=404, detail="Chat session not found")

    messages = parse_session_messages(session.messages_json)
    summary = serialize_session_summary(session)
    return ChatSessionDetailResponse(
        **summary.model_dump(),
        messages=messages,
    )

@router.get("/questions", response_model=List[QuestionResponse])
async def get_admin_questions(db: AsyncSession = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    stmt = select(HighFreqQuestion).order_by(
        desc(HighFreqQuestion.is_top), 
        desc(HighFreqQuestion.sort_weight), 
        desc(HighFreqQuestion.updated_at)
    )
    result = await db.execute(stmt)
    return [_serialize_question(q) for q in result.scalars().all()]

@router.post("/questions", response_model=QuestionResponse)
async def create_question(
    request: Request,
    question: QuestionCreate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    db_question = HighFreqQuestion(**question.model_dump())
    db.add(db_question)
    await db.commit()
    await db.refresh(db_question)
    await cache_invalidate("public_questions")
    await log_audit_action(
        current_admin=current_admin,
        request=request,
        module="question",
        action="create_question",
        target_id=str(db_question.id),
        target_type="question",
        details=f"新建高频问题: {db_question.question}",
    )
    return _serialize_question(db_question)

@router.put("/questions/{question_id}", response_model=QuestionResponse)
async def update_question(
    request: Request,
    question_id: int,
    question: QuestionCreate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    stmt = select(HighFreqQuestion).where(HighFreqQuestion.id == question_id)
    result = await db.execute(stmt)
    db_question = result.scalars().first()
    
    if db_question is None:
        raise HTTPException(status_code=404, detail="Question not found")
        
    for key, value in question.model_dump().items():
        setattr(db_question, key, value)
        
    await db.commit()
    await db.refresh(db_question)
    await cache_invalidate("public_questions")
    await log_audit_action(
        current_admin=current_admin,
        request=request,
        module="question",
        action="update_question",
        target_id=str(db_question.id),
        target_type="question",
        details=f"更新高频问题: {db_question.question}",
    )
    return _serialize_question(db_question)

@router.put("/questions/{question_id}/publish", response_model=QuestionResponse)
async def publish_question(
    request: Request,
    question_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    stmt = select(HighFreqQuestion).where(HighFreqQuestion.id == question_id)
    result = await db.execute(stmt)
    db_question = result.scalars().first()
    
    if db_question is None:
        raise HTTPException(status_code=404, detail="Question not found")
        
    db_question.status = "published"
    await db.commit()
    await db.refresh(db_question)
    
    await log_audit_action(
        current_admin=current_admin,
        request=request,
        module="question",
        action="publish_question",
        target_id=str(db_question.id),
        target_type="question",
        details=f"发布高频问题: {db_question.question}",
    )
    return _serialize_question(db_question)

@router.delete("/questions/{question_id}")
async def delete_question(
    request: Request,
    question_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    stmt = select(HighFreqQuestion).where(HighFreqQuestion.id == question_id)
    result = await db.execute(stmt)
    db_question = result.scalars().first()
    
    if db_question is None:
        raise HTTPException(status_code=404, detail="Question not found")
        
    await db.delete(db_question)
    await db.commit()
    await cache_invalidate("public_questions")
    await log_audit_action(
        current_admin=current_admin,
        request=request,
        module="question",
        action="delete_question",
        target_id=str(question_id),
        target_type="question",
        details=f"删除高频问题: {db_question.question}",
    )
    return {"message": "Question deleted successfully"}

class ConfigResponse(BaseModel):
    key: str
    value: str
    description: str
    updated_at: str

@router.get("/settings", response_model=List[ConfigResponse])
async def get_settings(db: AsyncSession = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    result = await db.execute(select(SystemConfig))
    return [
        ConfigResponse(
            key=c.key, 
            value=c.value, 
            description=c.description, 
            updated_at=c.updated_at.isoformat() if c.updated_at else ""
        ) for c in result.scalars().all()
    ]

class ConfigUpdateItem(BaseModel):
    key: str
    value: str

class ConfigUpdateRequest(BaseModel):
    configs: List[ConfigUpdateItem]

@router.put("/settings")
async def update_settings(
    request: Request,
    payload: ConfigUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    updated_keys: list[str] = []
    for item in payload.configs:
        result = await db.execute(select(SystemConfig).where(SystemConfig.key == item.key))
        config = result.scalars().first()
        if config:
            config.value = item.value
            updated_keys.append(item.key)
    
    await db.commit()
    await cache_invalidate("system_settings")
    for key in updated_keys:
        await log_audit_action(
            current_admin=current_admin,
            request=request,
            module="setting",
            action="update_setting",
            target_id=key,
            target_type="system_config",
            details=f"更新系统配置 {key}",
            metadata={"key": key},
        )
    return {"message": "Settings updated successfully"}

class PasswordUpdate(BaseModel):
    old_password: str
    new_password: str

@router.put("/password")
async def update_password(
    request: Request,
    payload: PasswordUpdate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    from security import verify_password
    if not verify_password(payload.old_password, current_admin.hashed_password):
        raise HTTPException(status_code=400, detail="原密码不正确")
        
    validate_password_strength(payload.new_password)
    current_admin.hashed_password = get_password_hash(payload.new_password)
    await db.commit()
    await log_audit_action(
        current_admin=current_admin,
        request=request,
        action="update_password",
        target_id=str(current_admin.id),
        target_type="user",
        details="修改了管理员密码",
    )
    return {"message": "Password updated successfully"}


def _mask_phone(phone: str | None) -> str | None:
    if not phone:
        return None
    if len(phone) < 7:
        return phone
    return f"{phone[:3]}****{phone[-4:]}"


def _infer_module(action: str | None) -> str | None:
    if not action:
        return None
    if action in {"login_password", "login_sms", "login_carrier", "logout"}:
        return "auth"
    if action.startswith("profile_"):
        return "profile"
    if action.endswith("_question") or action.startswith("publish_question"):
        return "question"
    if action == "update_agreement":
        return "agreement"
    if action == "update_setting":
        return "setting"
    if action in {"update_password", "update_user_status"}:
        return "admin"
    return None


ACTIONS_BY_MODULE = {
    "auth": {"login_password", "login_sms", "login_carrier", "logout"},
    "profile": {"profile_create", "profile_update", "profile_delete"},
    "question": {"create_question", "update_question", "publish_question", "delete_question"},
    "agreement": {"update_agreement"},
    "setting": {"update_setting"},
    "admin": {"update_user_status", "update_password"},
}


class OperationLogResponse(BaseModel):
    id: int
    created_at: str
    module: Optional[str]
    action: str
    terminal: Optional[str]
    result: Optional[str]
    actor_type: Optional[str]
    actor_name: Optional[str]
    actor_phone_masked: Optional[str]
    target_type: Optional[str]
    target_id: Optional[str]
    ip_address: Optional[str]
    details: Optional[str]
    request_id: Optional[str]
    user_agent: Optional[str]
    metadata: Optional[dict[str, Any]] = None


class OperationLogListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: List[OperationLogResponse]


def _serialize_operation_log(log: AuditLog, user: User | None) -> OperationLogResponse:
    actor_type = log.actor_type or ("admin" if log.admin_id else "user")
    actor_name = log.actor_name or (user.display_name if user and user.display_name else None)
    if not actor_name and user:
        actor_name = _mask_phone(user.phone)
    if not actor_name:
        actor_name = "系统" if actor_type == "system" else "匿名"

    actor_phone_masked = log.actor_phone_masked or _mask_phone(user.phone if user else None)
    metadata: dict[str, Any] | None = None
    if log.metadata_json:
        try:
            parsed_metadata = json.loads(log.metadata_json)
            if isinstance(parsed_metadata, dict):
                metadata = parsed_metadata
        except Exception:
            metadata = None

    return OperationLogResponse(
        id=log.id,
        created_at=log.created_at.isoformat() if log.created_at else "",
        module=log.module or _infer_module(log.action),
        action=log.action,
        terminal=log.terminal or ("admin_web" if actor_type == "admin" else None),
        result=log.result or "success",
        actor_type=actor_type,
        actor_name=actor_name,
        actor_phone_masked=actor_phone_masked,
        target_type=log.target_type,
        target_id=log.target_id,
        ip_address=log.ip_address,
        details=log.details,
        request_id=log.request_id,
        user_agent=log.user_agent,
        metadata=metadata,
    )


def _build_log_filters(
    *,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
    module: str | None = None,
    action: str | None = None,
    result: str | None = None,
    actor_type: str | None = None,
    target_type: str | None = None,
    terminal: str | None = None,
    keyword: str | None = None,
) -> list[Any]:
    filters: list[Any] = []
    if start_time is not None:
        filters.append(AuditLog.created_at >= start_time)
    if end_time is not None:
        filters.append(AuditLog.created_at <= end_time)
    if module:
        module_actions = ACTIONS_BY_MODULE.get(module, set())
        if module_actions:
            filters.append(
                or_(
                    AuditLog.module == module,
                    and_(AuditLog.module.is_(None), AuditLog.action.in_(module_actions)),
                )
            )
        else:
            filters.append(AuditLog.module == module)
    if action:
        filters.append(AuditLog.action == action)
    if result:
        if result == "success":
            filters.append(or_(AuditLog.result == result, AuditLog.result.is_(None)))
        else:
            filters.append(AuditLog.result == result)
    if actor_type:
        if actor_type == "admin":
            filters.append(or_(AuditLog.actor_type == actor_type, AuditLog.admin_id.isnot(None)))
        else:
            filters.append(AuditLog.actor_type == actor_type)
    if target_type:
        filters.append(AuditLog.target_type == target_type)
    if terminal:
        if terminal == "admin_web":
            filters.append(or_(AuditLog.terminal == terminal, AuditLog.admin_id.isnot(None)))
        else:
            filters.append(AuditLog.terminal == terminal)
    if keyword:
        exact_keyword = keyword.strip()
        like_keyword = f"%{keyword}%"
        keyword_filters = [
            AuditLog.details.ilike(like_keyword),
            AuditLog.target_id.ilike(like_keyword),
            AuditLog.actor_name.ilike(like_keyword),
            AuditLog.actor_phone_masked.ilike(like_keyword),
            AuditLog.request_id.ilike(like_keyword),
            AuditLog.ip_address.ilike(like_keyword),
            User.display_name.ilike(like_keyword),
        ]
        if exact_keyword:
            keyword_filters.append(User.phone_hash == phone_lookup_hash(exact_keyword))
        filters.append(or_(*keyword_filters))
    return filters


@router.get("/logs", response_model=OperationLogListResponse)
async def get_operation_logs(
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
    page: int = 1,
    page_size: int = 20,
    start_time: datetime | None = None,
    end_time: datetime | None = None,
    module: str | None = None,
    action: str | None = None,
    result: str | None = None,
    actor_type: str | None = None,
    target_type: str | None = None,
    terminal: str | None = None,
    keyword: str | None = None,
):
    del current_admin
    page = max(page, 1)
    page_size = max(1, min(page_size, 100))

    filters = _build_log_filters(
        start_time=start_time,
        end_time=end_time,
        module=module,
        action=action,
        result=result,
        actor_type=actor_type,
        target_type=target_type,
        terminal=terminal,
        keyword=keyword,
    )
    actor_join = func.coalesce(AuditLog.actor_user_id, AuditLog.admin_id) == User.id
    base_stmt = select(AuditLog, User).outerjoin(User, actor_join)
    if filters:
        base_stmt = base_stmt.where(*filters)

    total = await db.scalar(
        select(func.count(AuditLog.id))
        .select_from(AuditLog)
        .outerjoin(User, actor_join)
        .where(*filters)
    )

    result_stmt = base_stmt.order_by(desc(AuditLog.created_at), desc(AuditLog.id)).offset((page - 1) * page_size).limit(page_size)
    rows = await db.execute(result_stmt)
    items = [
        _serialize_operation_log(row.AuditLog, row.User)
        for row in rows.all()
    ]
    return OperationLogListResponse(
        total=total or 0,
        page=page,
        page_size=page_size,
        items=items,
    )


@router.get("/logs/{log_id}", response_model=OperationLogResponse)
async def get_operation_log_detail(
    log_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    del current_admin
    actor_join = func.coalesce(AuditLog.actor_user_id, AuditLog.admin_id) == User.id
    stmt = (
        select(AuditLog, User)
        .outerjoin(User, actor_join)
        .where(AuditLog.id == log_id)
    )
    result = await db.execute(stmt)
    row = result.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Log not found")
    return _serialize_operation_log(row.AuditLog, row.User)

class AuditLogResponse(BaseModel):
    id: int
    admin_name: str
    action: str
    target_id: Optional[str]
    details: Optional[str]
    created_at: str

@router.get("/audit-logs", response_model=List[AuditLogResponse])
async def get_audit_logs(db: AsyncSession = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    stmt = select(AuditLog, User).outerjoin(User, AuditLog.admin_id == User.id).order_by(desc(AuditLog.created_at)).limit(100)
    result = await db.execute(stmt)
    
    logs = []
    for row in result.all():
        log = row.AuditLog
        user = row.User
        admin_name = "未知管理员"
        if user:
            admin_name = user.display_name or _mask_phone(user.phone) or "未知管理员"
            
        logs.append(AuditLogResponse(
            id=log.id,
            admin_name=admin_name,
            action=log.action,
            target_id=log.target_id,
            details=log.details,
            created_at=log.created_at.isoformat()
        ))
    return logs

class AgreementResponse(BaseModel):
    id: int
    type: str
    title: str
    content: str
    updated_at: str

@router.get("/agreements", response_model=List[AgreementResponse])
async def get_agreements(db: AsyncSession = Depends(get_db), current_admin: User = Depends(get_current_admin)):
    result = await db.execute(select(Agreement).execution_options(populate_existing=True))
    return [
        AgreementResponse(
            id=a.id,
            type=a.type,
            title=a.title,
            content=a.content,
            updated_at=a.updated_at.isoformat() if a.updated_at else ""
        ) for a in result.scalars().all()
    ]

class AgreementUpdate(BaseModel):
    title: str
    content: str

@router.put("/agreements/{agreement_type}")
async def update_agreement(
    request: Request,
    agreement_type: str,
    payload: AgreementUpdate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
):
    from sqlalchemy import update
    
    logger.info(f"Received request to update agreement: {agreement_type}")
    logger.info(f"Payload title: {payload.title}, content length: {len(payload.content)}")
    
    result = await db.execute(select(Agreement).where(Agreement.type == agreement_type))
    agreement = result.scalars().first()
    
    try:
        if not agreement:
            logger.info(f"Agreement not found for type: {agreement_type}, creating a new one")
            agreement = Agreement(type=agreement_type, title=payload.title, content=payload.content)
            db.add(agreement)
        else:
            logger.info(f"Found agreement, old title: {agreement.title}, old content length: {len(agreement.content)}")
            # Using SQLAlchemy update with explicit execution options to bypass cache
            stmt = (
                update(Agreement)
                .where(Agreement.type == agreement_type)
                .values(title=payload.title, content=payload.content, updated_at=func.now())
                .execution_options(synchronize_session=False)
            )
            logger.info(f"Executing SQL update for {agreement_type}")
            await db.execute(stmt)
            
        await db.commit()
        await cache_invalidate(f"agreement_{agreement_type}")
        logger.info(f"Successfully committed changes to agreement: {agreement_type}")
    except Exception as e:
        logger.error(f"Failed to commit agreement update: {str(e)}")
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    
    await log_audit_action(
        current_admin=current_admin,
        request=request,
        module="agreement",
        action="update_agreement",
        target_id=agreement_type,
        target_type="agreement",
        details=f"更新了协议: {payload.title}",
    )
    return {"message": "Agreement updated successfully"}

# Public API for questions
public_router = APIRouter(prefix="/api/public", tags=["public"])

@public_router.get("/questions", response_model=List[QuestionResponse])
async def get_public_questions(db: AsyncSession = Depends(get_db)):
    stmt = select(HighFreqQuestion).where(HighFreqQuestion.status == "published").order_by(
        desc(HighFreqQuestion.is_top), 
        desc(HighFreqQuestion.sort_weight), 
        desc(HighFreqQuestion.click_count)
    )
    result = await db.execute(stmt)
    return [_serialize_question(q) for q in result.scalars().all()]

@public_router.post("/questions/{question_id}/click")
async def record_click(question_id: int, db: AsyncSession = Depends(get_db)):
    stmt = select(HighFreqQuestion).where(HighFreqQuestion.id == question_id)
    result = await db.execute(stmt)
    db_question = result.scalars().first()
    
    if db_question is None:
        raise HTTPException(status_code=404, detail="Question not found")
        
    db_question.click_count += 1
    await db.commit()
    return {"message": "Click recorded"}

@public_router.get("/agreements/{agreement_type}", response_model=AgreementResponse)
async def get_public_agreement(agreement_type: str, db: AsyncSession = Depends(get_db)):
    # Disable cache to ensure fresh data
    result = await db.execute(select(Agreement).where(Agreement.type == agreement_type).execution_options(populate_existing=True))
    agreement = result.scalars().first()
    
    if not agreement:
        raise HTTPException(status_code=404, detail="Agreement not found")
        
    return AgreementResponse(
        id=agreement.id,
        type=agreement.type,
        title=agreement.title,
        content=agreement.content,
        updated_at=agreement.updated_at.isoformat() if agreement.updated_at else ""
    )
