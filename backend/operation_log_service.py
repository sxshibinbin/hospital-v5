import json
import uuid
from typing import Any

from fastapi import Request
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession

from database import AsyncSessionLocal
from models import AuditLog, User

ALLOWED_TERMINALS = {"app", "pc", "admin_web"}


def _truncate(value: str | None, max_length: int) -> str | None:
    if value is None:
        return None
    if len(value) <= max_length:
        return value
    return value[:max_length]


def _mask_phone(phone: str | None) -> str | None:
    if not phone:
        return None
    if len(phone) < 7:
        return phone
    return f"{phone[:3]}****{phone[-4:]}"


def _resolve_terminal(request: Request | None, terminal: str | None) -> str | None:
    if terminal in ALLOWED_TERMINALS:
        return terminal
    if request is not None:
        request_terminal = request.headers.get("X-Client-Terminal", "").strip()
        if request_terminal in ALLOWED_TERMINALS:
            return request_terminal
    return terminal if terminal else None


def _resolve_request_id(request: Request | None) -> str:
    if request is not None:
        request_id = request.headers.get("X-Request-ID", "").strip()
        if request_id:
            return request_id
    return str(uuid.uuid4())


def _resolve_client_ip(request: Request | None) -> str | None:
    if request is None:
        return None

    forwarded_for = request.headers.get("x-forwarded-for", "").strip()
    if forwarded_for:
        first_ip = forwarded_for.split(",")[0].strip()
        if first_ip:
            return first_ip

    real_ip = request.headers.get("x-real-ip", "").strip()
    if real_ip:
        return real_ip

    if request.client and request.client.host:
        return request.client.host
    return None


def _resolve_user_agent(request: Request | None) -> str | None:
    if request is None:
        return None
    user_agent = request.headers.get("user-agent", "").strip()
    return _truncate(user_agent, 300) if user_agent else None


def _resolve_actor_name(
    actor_user: User | None,
    actor_name: str | None,
) -> str | None:
    if actor_name:
        return actor_name
    if actor_user is None:
        return None
    display_name = (actor_user.display_name or "").strip()
    if display_name:
        return display_name
    return _mask_phone(actor_user.phone)


async def log_operation_safe(
    *,
    action: str,
    module: str,
    request: Request | None = None,
    actor_user: User | None = None,
    actor_type: str = "user",
    actor_name: str | None = None,
    actor_phone_masked: str | None = None,
    terminal: str | None = None,
    result: str = "success",
    target_type: str | None = None,
    target_id: str | None = None,
    details: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    resolved_actor_name = _resolve_actor_name(actor_user, actor_name)
    resolved_actor_phone = actor_phone_masked or _mask_phone(actor_user.phone if actor_user else None)
    resolved_terminal = _resolve_terminal(request, terminal)
    payload = None if not metadata else json.dumps(metadata, ensure_ascii=False)

    try:
        resolved_admin_id = (
            actor_user.id
            if actor_user is not None and (actor_type == "admin" or actor_user.is_admin)
            else None
        )
        async with AsyncSessionLocal() as session:
            session.add(
                AuditLog(
                    admin_id=resolved_admin_id,
                    actor_user_id=actor_user.id if actor_user is not None else None,
                    actor_type=_truncate(actor_type, 20),
                    actor_name=_truncate(resolved_actor_name, 100),
                    actor_phone_masked=_truncate(resolved_actor_phone, 20),
                    terminal=_truncate(resolved_terminal, 20),
                    module=_truncate(module, 50),
                    action=_truncate(action, 50),
                    result=_truncate(result, 20),
                    target_type=_truncate(target_type, 50),
                    target_id=_truncate(str(target_id), 50) if target_id is not None else None,
                    details=_truncate(details, 500),
                    ip_address=_truncate(_resolve_client_ip(request), 64),
                    user_agent=_resolve_user_agent(request),
                    request_id=_truncate(_resolve_request_id(request), 64),
                    metadata_json=payload,
                )
            )
            await session.commit()
    except Exception as error:
        logger.warning("Failed to write operation log: {}", error)
