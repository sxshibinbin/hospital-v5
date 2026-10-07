import asyncio
import hmac
import os
import re
import secrets
import uuid
from datetime import timedelta

from alibabacloud_dypnsapi20170525.client import Client as DypnsapiClient
from alibabacloud_dypnsapi20170525 import models as dypnsapi_models
from alibabacloud_tea_openapi import models as open_api_models
from dotenv import load_dotenv
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import OAuth2PasswordRequestForm
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError
from sqlalchemy.future import select

from database import auth_cache, get_db
from db_encryption import phone_lookup_hash
from dependencies import get_current_user, oauth2_scheme
from models import ChatSession, ConsultationRecord, PatientProfile, User, get_beijing_time
from operation_log_service import log_operation_safe
from pydantic import BaseModel
from security import create_access_token, get_password_hash, verify_password, validate_password_strength
from sms_service import (
    SmsDeliveryError,
    SmsServiceConfigError,
    send_verification_code,
)
from sqlalchemy import delete, text
from typing import Any, Optional

load_dotenv()

router = APIRouter(prefix="/api/auth", tags=["auth"])

SMS_DAILY_LIMIT = 10
SMS_REQUEST_TTL_SECONDS = 86400
SMS_CODE_TTL_SECONDS = 300
SMS_RESEND_INTERVAL_SECONDS = 60
SMS_DEBUG_MODE = os.getenv("SMS_DEBUG_MODE", "false").strip().lower() in {"1", "true", "yes", "on"}
SMS_DEBUG_CODE = "123456"
APP_ENV = os.getenv("APP_ENV", os.getenv("ENVIRONMENT", "")).strip().lower()
if SMS_DEBUG_MODE and APP_ENV in {"prod", "production"}:
    raise RuntimeError("SMS_DEBUG_MODE must be disabled in production")
PASSWORD_LOGIN_MAX_ATTEMPTS = 5
PASSWORD_LOGIN_LOCK_TTL_SECONDS = 900
TOKEN_BLACKLIST_TTL_SECONDS = 86400 * 7
QR_LOGIN_TTL_SECONDS = 60
QR_LOGIN_POLL_INTERVAL_SECONDS = 2
QR_LOGIN_SCHEME = "hospital://pc-login"
INACTIVE_ACCOUNT_DETAIL = "账号已注销，无法继续使用"
PHONE_PATTERN = re.compile(r"^1[3-9]\d{9}$")

class UserCreate(BaseModel):
    phone: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class SendCodeRequest(BaseModel):
    phone: str

class SmsLoginRequest(BaseModel):
    phone: str
    code: str

class CarrierLoginRequest(BaseModel):
    carrier_token: str

class QrTokenRequest(BaseModel):
    session_id: str
    qr_token: str

class QrSessionResponse(BaseModel):
    session_id: str
    qr_payload: str
    pc_secret: str
    expires_at: str
    poll_interval_seconds: int = 2

class AdminSetup(BaseModel):
    phone: str
    password: str
    display_name: str

class CurrentUserResponse(BaseModel):
    id: int
    phone: str
    display_name: str
    default_profile_name: Optional[str] = None
    avatar_key: Optional[str] = None


class UpdateCurrentUserRequest(BaseModel):
    display_name: str
    avatar_key: Optional[str] = None


def _build_default_display_name(phone: str) -> str:
    return f"用户{phone[-4:]}"


def _normalize_phone(phone: str) -> str:
    normalized_phone = phone.strip().replace(" ", "").replace("-", "")
    if normalized_phone.startswith("+86"):
        normalized_phone = normalized_phone[3:]
    elif (
        normalized_phone.startswith("86")
        and len(normalized_phone) == 13
        and normalized_phone[2:3] == "1"
    ):
        normalized_phone = normalized_phone[2:]
    return normalized_phone


def _normalize_sms_code(code: str) -> str:
    """Normalize codes copied from SMS/input methods before comparison."""
    # SMS apps and mobile keyboards can add whitespace or emit full-width digits.
    return (
        str(code or "")
        .strip()
        .replace("０", "0")
        .replace("１", "1")
        .replace("２", "2")
        .replace("３", "3")
        .replace("４", "4")
        .replace("５", "5")
        .replace("６", "6")
        .replace("７", "7")
        .replace("８", "8")
        .replace("９", "9")
    )


def _mask_phone(phone: str) -> str:
    if len(phone) < 7:
        return "***"
    return f"{phone[:3]}****{phone[-4:]}"


def _ensure_valid_phone(phone: str) -> None:
    if not PHONE_PATTERN.fullmatch(phone):
        raise HTTPException(status_code=400, detail="请输入有效的中国大陆手机号")


def _ensure_account_is_active(user: User) -> None:
    if not user.is_active:
        raise HTTPException(status_code=403, detail=INACTIVE_ACCOUNT_DETAIL)


async def _find_user_by_phone(phone: str, db: AsyncSession) -> User | None:
    phone = _normalize_phone(phone)
    phone_hash = phone_lookup_hash(phone)
    result = await db.execute(select(User).where(User.phone_hash == phone_hash))
    hash_matches = result.scalars().all()
    if hash_matches:
        picked_user = _pick_existing_user(hash_matches)
        if picked_user and picked_user.is_active:
            return picked_user
        decrypted_matches = await _find_users_by_decrypted_phone(phone, db)
        return _pick_existing_user([*hash_matches, *decrypted_matches])

    result = await db.execute(
        select(User).where(text("users.phone = :phone")),
        {"phone": phone},
    )
    legacy_plain_matches = result.scalars().all()
    if legacy_plain_matches:
        return _pick_existing_user(legacy_plain_matches)

    decrypted_matches = await _find_users_by_decrypted_phone(phone, db)
    return _pick_existing_user(decrypted_matches)


async def _find_users_by_decrypted_phone(phone: str, db: AsyncSession) -> list[User]:
    stmt = select(User)
    result = await db.execute(stmt)
    matches: list[User] = []
    for candidate in result.scalars().all():
        if _normalize_phone(candidate.phone) == phone:
            matches.append(candidate)
    return matches


def _pick_existing_user(users: list[User]) -> User | None:
    distinct_users = {user.id: user for user in users if user.id is not None}
    if not distinct_users:
        return None
    # 已注销（有 deactivated_at）的账号永久失效，不参与登录匹配；
    # 仅封禁（is_active=False 且未注销）的账号保留，登录时报 403。
    candidates = [
        user for user in distinct_users.values() if user.deactivated_at is None
    ]
    if not candidates:
        return None
    return sorted(
        candidates,
        key=lambda user: (not bool(user.is_active), user.id or 0),
    )[0]


async def _sync_user_phone_lookup(user: User, db: AsyncSession) -> bool:
    expected_hash = phone_lookup_hash(user.phone)
    if user.phone_hash == expected_hash:
        return False
    result = await db.execute(
        select(User.id).where(User.phone_hash == expected_hash, User.id != user.id)
    )
    if result.scalar_one_or_none() is not None:
        return False
    user.phone_hash = expected_hash
    return True


def _resolve_display_name(
    user: User,
    default_profile_name: Optional[str],
) -> str:
    stored_display_name = (user.display_name or "").strip()
    if stored_display_name:
        return stored_display_name

    profile_name = (default_profile_name or "").strip()
    if profile_name:
        return profile_name

    return _build_default_display_name(user.phone)

def _create_dypns_client() -> DypnsapiClient:
    access_key_id = os.getenv("ALIBABA_CLOUD_ACCESS_KEY_ID", "").strip()
    access_key_secret = os.getenv("ALIBABA_CLOUD_ACCESS_KEY_SECRET", "").strip()
    if not access_key_id or not access_key_secret:
        raise HTTPException(
            status_code=503,
            detail="运营商一键登录暂未配置，请先设置阿里云 AccessKey",
        )

    config = open_api_models.Config(
        access_key_id=access_key_id,
        access_key_secret=access_key_secret,
        region_id=os.getenv("ALIBABA_CLOUD_DYPNAS_REGION_ID", "cn-hangzhou"),
    )
    return DypnsapiClient(config)

async def _resolve_phone_from_carrier_token(carrier_token: str) -> str:
    client = _create_dypns_client()
    request = dypnsapi_models.GetMobileRequest(
        access_token=carrier_token,
        out_id=str(uuid.uuid4()),
    )

    def execute() -> str:
        response = client.get_mobile(request)
        body = response.body
        if body is None or body.code != "OK":
            raise HTTPException(
                status_code=400,
                detail=body.message if body is not None else "运营商认证失败",
            )

        mobile = (
            body.get_mobile_result_dto.mobile
            if body.get_mobile_result_dto is not None
            else None
        )
        if not mobile:
            raise HTTPException(status_code=400, detail="未获取到本机号码")
        return mobile

    try:
        return await asyncio.to_thread(execute)
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(
            status_code=502,
            detail=f"运营商认证服务异常：{error}",
        ) from error

async def _issue_token_for_phone(phone: str, db: AsyncSession) -> tuple[Token, User]:
    phone = _normalize_phone(phone)
    user = await _find_user_by_phone(phone, db)

    if not user:
        # 无活跃账号（或仅有已注销账号）→ 创建全新账号，旧注销账号保留不动。
        user = User(
            phone=phone,
            phone_hash=phone_lookup_hash(phone),
            display_name=_build_default_display_name(phone),
        )
        db.add(user)
        try:
            await db.commit()
            await db.refresh(user)
        except IntegrityError:
            await db.rollback()
            user = await _find_user_by_phone(phone, db)
            if user is None:
                raise
            _ensure_account_is_active(user)
    else:
        _ensure_account_is_active(user)
        if await _sync_user_phone_lookup(user, db):
            db.add(user)
            await db.commit()
            await db.refresh(user)

    access_token = create_access_token(data={"sub": str(user.id)})
    return Token(access_token=access_token, token_type="bearer"), user


async def _log_auth_operation(
    *,
    request: Request | None,
    action: str,
    result: str,
    details: str,
    actor_user: User | None = None,
    actor_name: str | None = None,
    actor_phone_masked: str | None = None,
    target_id: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    await log_operation_safe(
        request=request,
        actor_user=actor_user,
        actor_type="admin" if actor_user and actor_user.is_admin else "user",
        actor_name=actor_name,
        actor_phone_masked=actor_phone_masked,
        module="auth",
        action=action,
        result=result,
        target_type="user",
        target_id=target_id,
        details=details,
        metadata=metadata,
    )

def _require_client_terminal(request: Request, expected: str) -> None:
    terminal = request.headers.get("X-Client-Terminal", "").strip().lower()
    if terminal != expected:
        raise HTTPException(status_code=403, detail="Invalid client terminal")


def _qr_secret_matches(value: str, expected_hash: str | None) -> bool:
    if not value or not expected_hash:
        return False
    return hmac.compare_digest(auth_cache.hash_qr_secret(value), expected_hash)


def _qr_log_id(session_id: str) -> str:
    return session_id[:8]


async def _load_qr_session(session_id: str) -> dict[str, str]:
    if not re.fullmatch(r"[0-9a-fA-F-]{36}", session_id):
        raise HTTPException(status_code=400, detail="Invalid QR session")
    session = await auth_cache.get_qr_login(session_id)
    if not session:
        raise HTTPException(status_code=400, detail="QR code expired or invalid")
    return session


def _qr_session_result(session: dict[str, str]) -> dict[str, str]:
    return {
        "status": session.get("status", "missing"),
        "expires_at": session.get("expires_at", ""),
        **(
            {"scanned_at": session["scanned_at"]}
            if session.get("scanned_at")
            else {}
        ),
    }


@router.post("/qr/session", response_model=QrSessionResponse)
async def create_qr_session(request: Request):
    _require_client_terminal(request, "pc")
    session_id = str(uuid.uuid4())
    qr_token = secrets.token_urlsafe(32)
    pc_secret = secrets.token_urlsafe(32)
    created_at = get_beijing_time()
    expires_at = created_at + timedelta(seconds=QR_LOGIN_TTL_SECONDS)
    await auth_cache.create_qr_login(
        session_id=session_id,
        qr_token_hash=auth_cache.hash_qr_secret(qr_token),
        pc_secret_hash=auth_cache.hash_qr_secret(pc_secret),
        created_at=created_at.isoformat(),
        expires_at=expires_at.isoformat(),
        ttl_seconds=QR_LOGIN_TTL_SECONDS,
    )
    await _log_auth_operation(
        request=request,
        action="qr_login_create",
        result="success",
        details="Create QR login session",
        target_id=_qr_log_id(session_id),
    )
    qr_payload = (
        f"{QR_LOGIN_SCHEME}?sid={session_id}&qt={qr_token}&v=1"
    )
    return QrSessionResponse(
        session_id=session_id,
        qr_payload=qr_payload,
        pc_secret=pc_secret,
        expires_at=expires_at.isoformat(),
        poll_interval_seconds=QR_LOGIN_POLL_INTERVAL_SECONDS,
    )


@router.get("/qr/session/{session_id}/status")
async def get_qr_session_status(session_id: str, request: Request):
    _require_client_terminal(request, "pc")
    pc_secret = request.headers.get("X-QR-PC-Secret", "")
    session = await _load_qr_session(session_id)
    if not _qr_secret_matches(pc_secret, session.get("pc_secret_hash")):
        raise HTTPException(status_code=403, detail="Invalid QR session secret")

    status = session.get("status", "missing")
    if status == "confirmed":
        status, access_token = await auth_cache.qr_consume(
            session_id,
            consumed_at=get_beijing_time().isoformat(),
        )
        if status == "consumed" and access_token:
            await _log_auth_operation(
                request=request,
                action="qr_login_consume",
                result="success",
                details="Consume QR login token",
                target_id=_qr_log_id(session_id),
            )
            return {
                "status": "confirmed",
                "access_token": access_token,
                "token_type": "bearer",
            }
        session = await _load_qr_session(session_id)
        status = session.get("status", "missing")

    return _qr_session_result({**session, "status": status})


async def _validate_qr_app_request(
    payload: QrTokenRequest,
    current_user: User,
) -> dict[str, str]:
    session = await _load_qr_session(payload.session_id)
    if not _qr_secret_matches(payload.qr_token, session.get("qr_token_hash")):
        raise HTTPException(status_code=403, detail="Invalid QR code")
    return session


@router.post("/qr/scan")
async def scan_qr_login(
    request: Request,
    payload: QrTokenRequest,
    current_user: User = Depends(get_current_user),
):
    _require_client_terminal(request, "app")
    session = await _validate_qr_app_request(payload, current_user)
    status = session.get("status", "missing")
    if status == "scanned" and session.get("user_id") == str(current_user.id):
        return {
            "status": "scanned",
            "session_id": payload.session_id,
            "terminal_name": "PC 网页端",
            "scanned_at": session.get("scanned_at", ""),
            "confirm_expires_at": session.get("expires_at", ""),
        }
    if status != "pending":
        raise HTTPException(status_code=409, detail="QR code has already been processed")
    result = await auth_cache.qr_scan(
        payload.session_id,
        user_id=current_user.id,
        scanned_at=get_beijing_time().isoformat(),
    )
    if result != "scanned":
        raise HTTPException(status_code=409, detail="QR code has already been processed")
    session = await _load_qr_session(payload.session_id)
    await _log_auth_operation(
        request=request,
        action="qr_login_scan",
        result="success",
        details="Scan QR login session",
        actor_user=current_user,
        target_id=_qr_log_id(payload.session_id),
    )
    return {
        "status": "scanned",
        "session_id": payload.session_id,
        "terminal_name": "PC 网页端",
        "scanned_at": session.get("scanned_at", ""),
        "confirm_expires_at": session.get("expires_at", ""),
    }


@router.post("/qr/confirm")
async def confirm_qr_login(
    request: Request,
    payload: QrTokenRequest,
    current_user: User = Depends(get_current_user),
):
    _require_client_terminal(request, "app")
    session = await _validate_qr_app_request(payload, current_user)
    status = session.get("status", "missing")
    if status == "confirmed" and session.get("user_id") == str(current_user.id):
        return {"status": "confirmed", "session_id": payload.session_id}
    if status != "scanned" or session.get("user_id") != str(current_user.id):
        raise HTTPException(status_code=409, detail="QR code is not awaiting confirmation")
    access_token = create_access_token(data={"sub": str(current_user.id)})
    result = await auth_cache.qr_confirm(
        payload.session_id,
        user_id=current_user.id,
        confirmed_at=get_beijing_time().isoformat(),
        access_token=access_token,
    )
    if result != "confirmed":
        raise HTTPException(status_code=409, detail="QR code is no longer valid")
    await _log_auth_operation(
        request=request,
        action="qr_login_confirm",
        result="success",
        details="Confirm QR login session",
        actor_user=current_user,
        target_id=_qr_log_id(payload.session_id),
    )
    return {"status": "confirmed", "session_id": payload.session_id}


@router.post("/qr/reject")
async def reject_qr_login(
    request: Request,
    payload: QrTokenRequest,
    current_user: User = Depends(get_current_user),
):
    _require_client_terminal(request, "app")
    session = await _validate_qr_app_request(payload, current_user)
    if session.get("status") not in {"pending", "scanned"}:
        raise HTTPException(status_code=409, detail="QR code has already been processed")
    result = await auth_cache.qr_reject(
        payload.session_id,
        rejected_at=get_beijing_time().isoformat(),
    )
    if result != "rejected":
        raise HTTPException(status_code=409, detail="QR code has already been processed")
    await _log_auth_operation(
        request=request,
        action="qr_login_reject",
        result="success",
        details="Reject QR login session",
        actor_user=current_user,
        target_id=_qr_log_id(payload.session_id),
    )
    return {"status": "rejected", "session_id": payload.session_id}


@router.post("/qr/session/{session_id}/cancel")
async def cancel_qr_login(session_id: str, request: Request):
    _require_client_terminal(request, "pc")
    pc_secret = request.headers.get("X-QR-PC-Secret", "")
    session = await _load_qr_session(session_id)
    if not _qr_secret_matches(pc_secret, session.get("pc_secret_hash")):
        raise HTTPException(status_code=403, detail="Invalid QR session secret")
    result = await auth_cache.qr_cancel(
        session_id,
        cancelled_at=get_beijing_time().isoformat(),
    )
    return {"status": result, "session_id": session_id}


@router.post("/send_code")
async def send_code(request: SendCodeRequest):
    phone = _normalize_phone(request.phone)
    _ensure_valid_phone(phone)

    if not await auth_cache.try_mark_sms_cooldown(phone, SMS_RESEND_INTERVAL_SECONDS):
        raise HTTPException(
            status_code=429,
            detail=f"验证码发送过于频繁，请 {SMS_RESEND_INTERVAL_SECONDS} 秒后重试",
        )

    count = await auth_cache.get_sms_request_count(phone)
    if count >= SMS_DAILY_LIMIT:
        raise HTTPException(status_code=429, detail="今日验证码发送次数已达上限")

    code = "".join(secrets.choice("0123456789") for _ in range(6))
    await auth_cache.store_sms_code(phone, code, SMS_CODE_TTL_SECONDS)

    if SMS_DEBUG_MODE:
        # 调试模式：硬编码 123456 与随机验证码同时有效（登录时直接放行 123456）
        logger.warning(
            "SMS debug mode is enabled; verification code generated without provider delivery: phone={}",
            _mask_phone(phone),
        )
        await auth_cache.increment_sms_request_count(phone, SMS_REQUEST_TTL_SECONDS)
        return {
            "message": "Code generated in debug mode; SMS was not sent",
            "code": code,
            "debug_mode": True,
            "debug_code": SMS_DEBUG_CODE,
            "sms_delivered": False,
        }

    try:
        send_result = await send_verification_code(phone, code)
    except SmsServiceConfigError as error:
        await auth_cache.delete_sms_code(phone)
        await auth_cache.clear_sms_cooldown(phone)
        raise HTTPException(status_code=503, detail=str(error)) from error
    except SmsDeliveryError as error:
        await auth_cache.delete_sms_code(phone)
        await auth_cache.clear_sms_cooldown(phone)
        raise HTTPException(status_code=502, detail=str(error)) from error

    await auth_cache.increment_sms_request_count(phone, SMS_REQUEST_TTL_SECONDS)
    return {
        "message": "Code sent successfully",
        "debug_mode": False,
        "sms_delivered": True,
        "request_id": send_result.request_id,
    }

@router.post("/register", response_model=Token)
async def register(user_data: UserCreate, db: AsyncSession = Depends(get_db)):
    phone = _normalize_phone(user_data.phone)
    if await _find_user_by_phone(phone, db):
        raise HTTPException(status_code=400, detail="Phone already registered")
        
    hashed_password = get_password_hash(validate_password_strength(user_data.password))
    new_user = User(
        phone=phone,
        phone_hash=phone_lookup_hash(phone),
        hashed_password=hashed_password,
        display_name=_build_default_display_name(phone),
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    
    access_token = create_access_token(data={"sub": str(new_user.id)})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/login", response_model=Token)
async def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    phone = _normalize_phone(form_data.username)

    if await auth_cache.is_login_locked(phone):
        await _log_auth_operation(
            request=request,
            action="login_password",
            result="failure",
            details="密码登录失败：账号已锁定",
            actor_name=_mask_phone(phone),
            actor_phone_masked=_mask_phone(phone),
            target_id=_mask_phone(phone),
            metadata={"reason": "locked"},
        )
        raise HTTPException(status_code=429, detail="Account locked for 15 minutes due to multiple failed attempts")

    user = await _find_user_by_phone(phone, db)
    
    if not user:
        await auth_cache.register_failed_login(
            phone,
            max_attempts=PASSWORD_LOGIN_MAX_ATTEMPTS,
            lock_ttl_seconds=PASSWORD_LOGIN_LOCK_TTL_SECONDS,
        )
        await _log_auth_operation(
            request=request,
            action="login_password",
            result="failure",
            details="密码登录失败：账号或密码错误",
            actor_name=_mask_phone(phone),
            actor_phone_masked=_mask_phone(phone),
            target_id=_mask_phone(phone),
            metadata={"reason": "user_not_found"},
        )
        raise HTTPException(status_code=400, detail="Incorrect phone or password")

    try:
        _ensure_account_is_active(user)
    except HTTPException as error:
        await _log_auth_operation(
            request=request,
            action="login_password",
            result="failure",
            details=f"密码登录失败：{error.detail}",
            actor_user=user,
            target_id=str(user.id),
            metadata={"reason": "inactive_account"},
        )
        raise

    if not user.hashed_password or not verify_password(form_data.password, user.hashed_password):
        await auth_cache.register_failed_login(
            phone,
            max_attempts=PASSWORD_LOGIN_MAX_ATTEMPTS,
            lock_ttl_seconds=PASSWORD_LOGIN_LOCK_TTL_SECONDS,
        )
        await _log_auth_operation(
            request=request,
            action="login_password",
            result="failure",
            details="密码登录失败：账号或密码错误",
            actor_user=user,
            target_id=str(user.id),
            metadata={"reason": "password_mismatch"},
        )
        raise HTTPException(status_code=400, detail="Incorrect phone or password")

    if user.deactivated_at is not None:
        await _log_auth_operation(
            request=request,
            action="login_password",
            result="failure",
            details="密码登录失败：账号已注销",
            actor_user=user,
            target_id=str(user.id),
            metadata={"reason": "deactivated_account"},
        )
        raise HTTPException(status_code=403, detail="该账号已注销，请重新注册")

    await auth_cache.reset_failed_logins(phone)
    if await _sync_user_phone_lookup(user, db):
        db.add(user)
        await db.commit()
        await db.refresh(user)
    access_token = create_access_token(data={"sub": str(user.id)})
    await _log_auth_operation(
        request=request,
        action="login_password",
        result="success",
        details="密码登录成功",
        actor_user=user,
        target_id=str(user.id),
    )
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/login/sms", response_model=Token)
async def login_with_sms(
    request: Request,
    payload: SmsLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    phone = _normalize_phone(payload.phone)
    submitted_code = _normalize_sms_code(payload.code)
    try:
        _ensure_valid_phone(phone)
    except HTTPException:
        await _log_auth_operation(
            request=request,
            action="login_sms",
            result="failure",
            details="短信登录失败：手机号格式错误",
            actor_name=_mask_phone(phone),
            actor_phone_masked=_mask_phone(phone),
            target_id=_mask_phone(phone),
            metadata={"reason": "invalid_phone"},
        )
        raise

    debug_code_ok = SMS_DEBUG_MODE and submitted_code == SMS_DEBUG_CODE
    saved_code = await auth_cache.get_sms_code(phone)
    if not debug_code_ok and (not saved_code or saved_code != submitted_code):
        await _log_auth_operation(
            request=request,
            action="login_sms",
            result="failure",
            details="短信登录失败：验证码无效或已过期",
            actor_name=_mask_phone(phone),
            actor_phone_masked=_mask_phone(phone),
            target_id=_mask_phone(phone),
            metadata={"reason": "invalid_code"},
        )
        raise HTTPException(status_code=400, detail="Invalid or expired verification code")

    if not debug_code_ok:
        await auth_cache.delete_sms_code(phone)
    try:
        token, user = await _issue_token_for_phone(phone, db)
    except HTTPException as error:
        await _log_auth_operation(
            request=request,
            action="login_sms",
            result="failure",
            details=f"短信登录失败：{error.detail}",
            actor_name=_mask_phone(phone),
            actor_phone_masked=_mask_phone(phone),
            target_id=_mask_phone(phone),
            metadata={"reason": "account_error"},
        )
        raise
    await _log_auth_operation(
        request=request,
        action="login_sms",
        result="success",
        details="短信登录成功",
        actor_user=user,
        target_id=str(user.id),
    )
    return token

@router.post("/login/carrier", response_model=Token)
async def login_with_carrier(
    request: Request,
    payload: CarrierLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    try:
        phone = await _resolve_phone_from_carrier_token(payload.carrier_token)
        token, user = await _issue_token_for_phone(phone, db)
    except HTTPException as error:
        await _log_auth_operation(
            request=request,
            action="login_carrier",
            result="failure",
            details=f"一键登录失败：{error.detail}",
            actor_name="运营商登录",
            metadata={"reason": "carrier_error"},
        )
        raise
    except Exception:
        await _log_auth_operation(
            request=request,
            action="login_carrier",
            result="failure",
            details="一键登录失败：服务异常",
            actor_name="运营商登录",
            metadata={"reason": "carrier_exception"},
        )
        raise

    await _log_auth_operation(
        request=request,
        action="login_carrier",
        result="success",
        details="一键登录成功",
        actor_user=user,
        target_id=str(user.id),
    )
    return token

@router.get("/check-admin")
async def check_admin_exists(db: AsyncSession = Depends(get_db)):
    stmt = select(User).where(User.is_admin == True)
    result = await db.execute(stmt)
    admin = result.scalars().first()
    return {"has_admin": admin is not None}

@router.post("/setup", response_model=Token)
async def setup_admin(payload: AdminSetup, db: AsyncSession = Depends(get_db)):
    stmt = select(User).where(User.is_admin == True)
    result = await db.execute(stmt)
    if result.scalars().first():
        raise HTTPException(status_code=400, detail="管理员已存在，无法重复初始化")

    validate_password_strength(payload.password)

    phone = _normalize_phone(payload.phone)
    if await _find_user_by_phone(phone, db):
        raise HTTPException(status_code=400, detail="该手机号已注册，无法作为管理员账号")

    hashed_password = get_password_hash(payload.password)
    admin_user = User(
        phone=phone,
        phone_hash=phone_lookup_hash(phone),
        display_name=payload.display_name.strip(),
        hashed_password=hashed_password,
        is_admin=True,
    )
    db.add(admin_user)
    await db.commit()
    await db.refresh(admin_user)

    access_token = create_access_token(data={"sub": str(admin_user.id)})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/logout")
async def logout(
    request: Request,
    token: str = Depends(oauth2_scheme),
    _current_user: User = Depends(get_current_user),
):
    await auth_cache.blacklist_token(token, TOKEN_BLACKLIST_TTL_SECONDS)
    await _log_auth_operation(
        request=request,
        action="logout",
        result="success",
        details="退出登录",
        actor_user=_current_user,
        target_id=str(_current_user.id),
    )
    return {"message": "Logged out successfully"}

@router.post("/me/deactivate")
async def deactivate_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile_ids = select(PatientProfile.id).where(
        PatientProfile.user_id == current_user.id
    ).scalar_subquery()
    await db.execute(
        delete(ConsultationRecord).where(
            ConsultationRecord.profile_id.in_(profile_ids)
        )
    )
    await db.execute(
        delete(PatientProfile).where(PatientProfile.user_id == current_user.id)
    )
    await db.execute(
        delete(ChatSession).where(ChatSession.user_id == current_user.id)
    )

    # 注销 = 永久失效：释放手机号（phone_hash 置空），同一手机号之后登录会创建全新账号。
    # 加密手机号 / 昵称等历史字段保留，供后台审计追溯。
    current_user.is_active = False
    current_user.deactivated_at = get_beijing_time()
    current_user.phone_hash = None
    current_user.avatar_key = None
    db.add(current_user)
    await db.commit()
    await auth_cache.blacklist_token(token, TOKEN_BLACKLIST_TTL_SECONDS)
    return {"message": "Account deactivated successfully"}

@router.get("/me", response_model=CurrentUserResponse)
async def read_current_user(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = (
        select(PatientProfile)
        .where(PatientProfile.user_id == current_user.id)
        .order_by(PatientProfile.created_at.asc())
    )
    result = await db.execute(stmt)
    default_profile = result.scalars().first()
    default_profile_name = default_profile.name if default_profile else None
    display_name = _resolve_display_name(current_user, default_profile_name)

    return CurrentUserResponse(
        id=current_user.id,
        phone=current_user.phone,
        display_name=display_name,
        default_profile_name=default_profile_name,
        avatar_key=current_user.avatar_key,
    )


@router.put("/me", response_model=CurrentUserResponse)
async def update_current_user(
    payload: UpdateCurrentUserRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    display_name = payload.display_name.strip()
    if not display_name:
        raise HTTPException(status_code=400, detail="昵称不能为空")

    current_user.display_name = display_name
    current_user.avatar_key = payload.avatar_key.strip() if payload.avatar_key else None
    db.add(current_user)
    await db.commit()
    await db.refresh(current_user)

    stmt = (
        select(PatientProfile)
        .where(PatientProfile.user_id == current_user.id)
        .order_by(PatientProfile.created_at.asc())
    )
    result = await db.execute(stmt)
    default_profile = result.scalars().first()
    default_profile_name = default_profile.name if default_profile else None

    return CurrentUserResponse(
        id=current_user.id,
        phone=current_user.phone,
        display_name=_resolve_display_name(current_user, default_profile_name),
        default_profile_name=default_profile_name,
        avatar_key=current_user.avatar_key,
    )
