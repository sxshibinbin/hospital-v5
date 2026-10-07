import json
import os
import asyncio
import base64
from contextlib import asynccontextmanager, suppress
from pathlib import Path
import time
from fastapi import FastAPI, Request, UploadFile, File, Form, Response, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sse_starlette.sse import EventSourceResponse
from typing import List, Dict, Optional
import uvicorn
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession

from logger_config import setup_logger
from agents import stream_health_report, stream_normal_chat, stream_medical_chat, strip_image_exif, upload_files_for_extraction, polish_medical_query
from database import (
    AsyncSessionLocal,
    check_redis_connection,
    close_db_connections,
    close_redis_connection,
    get_database_dialect,
    get_masked_database_url,
    get_redis_client,
    get_db,
    init_db,
    seed_default_data,
)
from security import decode_access_token
from dependencies import get_current_user
from models import ChatSession, ChatUploadedFile, HighFreqQuestion, PatientProfile, User
from sqlalchemy.future import select
from memory import get_memory_manager
from middleware import RateLimitMiddleware
from ai_label import build_ai_label_meta, new_content_id
from safety import check_input, check_output
from safety.constants import REPLIES
from safety.recorder import record_event
from safety import models as safety_models  # noqa: F401 - register ORM tables before create_all
from safety.seed import seed_safety_defaults

from routers import auth, profiles, consultations, admin, chat_sessions, health, feedback, ai_safety
from iot_subscription.router import router as iot_router, log_writer as iot_log_writer
from iot_subscription.device_api import router as iot_device_api_router
from iot_subscription.alarm_api import router as iot_alarm_api_router
from iot_subscription.event_api import router as iot_event_api_router
from iot_subscription.database import init_pool as init_iot_pool, close_pool as close_iot_pool
from iot_subscription.file_monitor import file_monitor_loop
from health_report import (
    build_health_report_facts,
    build_latest_metric_response,
    should_handle_health_report,
    should_handle_latest_metric,
)


DEFAULT_CORS_ALLOWED_ORIGINS = (
    "http://localhost",
    "http://localhost:3000",
    "http://localhost:5173",
    "http://localhost:5174",
    "http://localhost:8080",
    "http://localhost:8081",
    "http://localhost:8082",
    "http://localhost:8083",
    "http://127.0.0.1",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:5173",
    "http://127.0.0.1:5174",
    "http://127.0.0.1:8080",
    "http://127.0.0.1:8081",
    "http://127.0.0.1:8082",
    "http://127.0.0.1:8083",
    "http://localhost:49230",
    "http://localhost:49235",
    "http://localhost:49367",
    "http://localhost:54513",
)


def get_cors_allowed_origins() -> List[str]:
    configured_origins = os.getenv("CORS_ALLOWED_ORIGINS", "").strip()
    if configured_origins:
        return [
            origin.strip().rstrip("/")
            for origin in configured_origins.split(",")
            if origin.strip()
        ]
    # 鍥哄畾绔彛 + 甯歌寮€鍙戠鍙?
    return [
        "http://localhost",
        "http://localhost:5000",   # Flutter Web 鍥哄畾绔彛
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:5174",
        "http://localhost:8080",
        "http://localhost:8081",
        "http://localhost:8082",
        "http://localhost:8083",
        "http://127.0.0.1",
        "http://127.0.0.1:5000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:5174",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:8081",
        "http://127.0.0.1:8082",
        "http://127.0.0.1:8083",
    ]


CORS_ALLOWED_ORIGINS = get_cors_allowed_origins()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    setup_logger()
    iot_monitor_task = None
    logger.info(
        "Database configuration:"
        f" dialect={get_database_dialect()},"
        f" url={get_masked_database_url()}"
    )
    logger.info(f"CORS allowed origins: {CORS_ALLOWED_ORIGINS}")
    await init_db()
    await seed_default_data()
    await seed_safety_defaults()
    try:
        await check_redis_connection()
        logger.info("Redis connection successful.")
    except Exception as e:
        logger.error(f"Redis connection failed: {e}")
    try:
        init_iot_pool()
        iot_monitor_task = asyncio.create_task(file_monitor_loop())
    except Exception as e:
        logger.error(f"IoT file monitor startup failed: {e}")
    yield
    if iot_monitor_task is not None:
        iot_monitor_task.cancel()
        with suppress(asyncio.CancelledError):
            await iot_monitor_task
    try:
        iot_log_writer.close()
        close_iot_pool()
    except Exception as e:
        logger.error(f"Error closing IoT subscription resources: {e}")
    try:
        await close_redis_connection()
    except Exception as e:
        logger.error(f"Error closing redis connection: {e}")
    try:
        await close_db_connections()
    except Exception as e:
        logger.error(f"Error closing database connections: {e}")

app = FastAPI(lifespan=lifespan)


@app.middleware("http")
async def dynamic_cors_middleware(request: Request, call_next):
    """鍔ㄦ€佸鐞?localhost 鍜?127.0.0.1 鐨?CORS 璇锋眰"""
    origin = request.headers.get("origin", "")
    is_local = (
        origin.startswith("http://localhost:")
        or origin.startswith("http://127.0.0.1:")
        or origin == "http://localhost"
        or origin == "http://127.0.0.1"
    )

    # 澶勭悊 CORS 棰勬璇锋眰 (OPTIONS)
    if request.method == "OPTIONS" and is_local:
        from fastapi.responses import PlainTextResponse
        return PlainTextResponse(
            content="",
            status_code=204,
            headers={
                "Access-Control-Allow-Origin": origin,
                "Access-Control-Allow-Credentials": "true",
                "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
                "Access-Control-Allow-Headers": "*",
            },
        )

    response = await call_next(request)

    if is_local:
        response.headers["Access-Control-Allow-Origin"] = origin
        response.headers["Access-Control-Allow-Credentials"] = "true"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "*"

    return response


@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    
    # 鑾峰彇瀹㈡埛绔?IP锛屽鏋滄病鏈夊垯鏍囪涓?Unknown
    client_ip = request.client.host if request.client else "Unknown"
    method = request.method
    url = request.url.path
    query = request.url.query
    query_str = f"?{query}" if query else ""
    
    logger.info(f"Incoming Request: {method} {url}{query_str} from {client_ip}")
    
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        logger.info(f"Request Completed: {method} {url}{query_str} - Status: {response.status_code} - Time: {process_time:.4f}s")
        return response
    except Exception as e:
        process_time = time.time() - start_time
        logger.exception(f"Request Failed: {method} {url}{query_str} - Error: {str(e)} - Time: {process_time:.4f}s")
        raise


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


MAX_UPLOAD_SIZE = 10 * 1024 * 1024  # 10 MB
MAX_ATTACHMENT_FILES = 5


@app.middleware("http")
async def limit_request_size(request: Request, call_next):
    content_length = request.headers.get("content-length")
    if content_length and int(content_length) > MAX_UPLOAD_SIZE:
        from fastapi.responses import JSONResponse
        return JSONResponse(
            status_code=413,
            content={"detail": "璇锋眰浣撳ぇ灏忚秴杩囬檺鍒?(鏈€澶?10MB)"},
        )
    return await call_next(request)


# Rate limiting middleware (innermost, runs first before routes)
rate_limit_middleware = RateLimitMiddleware(get_redis_client)
app.middleware("http")(rate_limit_middleware)


app.include_router(health.router)
app.include_router(auth.router)
app.include_router(profiles.router)
app.include_router(consultations.router)
app.include_router(chat_sessions.router)
app.include_router(feedback.router)
app.include_router(ai_safety.router)
app.include_router(admin.router)
app.include_router(admin.public_router)
app.include_router(iot_router)
app.include_router(iot_device_api_router)
app.include_router(iot_alarm_api_router)
app.include_router(iot_event_api_router)

ALLOWED_ATTACHMENT_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".webp"}
ALLOWED_ATTACHMENT_MIME_TYPES = {"application/pdf"}


def parse_history_payload(raw_history: Optional[str]) -> List[Dict[str, str]]:
    if not raw_history:
        return []

    try:
        parsed_history = json.loads(raw_history)
    except json.JSONDecodeError as exc:
        raise ValueError("history 瀛楁涓嶆槸鍚堟硶 JSON") from exc

    if not isinstance(parsed_history, list):
        raise ValueError("history must be a JSON list")

    history: List[Dict[str, str]] = []
    for item in parsed_history:
        if not isinstance(item, dict):
            continue
        role = item.get("role")
        content = item.get("content")
        if role in {"user", "assistant"} and isinstance(content, str) and content.strip():
            history.append({"role": role, "content": content})

    return history


def parse_bool_payload(value: Optional[str]) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def parse_string_list_payload(raw_value: Optional[str]) -> List[str]:
    if not raw_value:
        return []

    try:
        parsed_value = json.loads(raw_value)
    except json.JSONDecodeError as exc:
        raise ValueError("context_file_ids 瀛楁涓嶆槸鍚堟硶 JSON") from exc

    if not isinstance(parsed_value, list):
        raise ValueError("context_file_ids must be a JSON list")

    return list(
        dict.fromkeys(
            item.strip() for item in parsed_value if isinstance(item, str) and item.strip()
        )
    )


async def ensure_chat_session_access(
    db: AsyncSession,
    current_user: User,
    session_id: Optional[int],
) -> Optional[ChatSession]:
    if session_id is None:
        return None

    if session_id <= 0:
        raise HTTPException(status_code=400, detail="浼氳瘽 ID 鏃犳晥")

    stmt = select(ChatSession).where(
        ChatSession.id == session_id,
        ChatSession.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    session = result.scalars().first()
    if session is None:
        raise HTTPException(status_code=404, detail="鏈壘鍒板搴旂殑瀵硅瘽浼氳瘽")

    return session


async def ensure_chat_file_access(
    db: AsyncSession,
    current_user: User,
    file_ids: List[str],
) -> None:
    if not file_ids:
        return

    stmt = select(ChatUploadedFile.file_id).where(
        ChatUploadedFile.user_id == current_user.id,
        ChatUploadedFile.file_id.in_(file_ids),
    )
    result = await db.execute(stmt)
    owned_file_ids = {row[0] for row in result.all()}
    missing_file_ids = [file_id for file_id in file_ids if file_id not in owned_file_ids]
    if missing_file_ids:
        logger.warning(
            "Blocked cross-user chat file access: user_id={}, file_count={}",
            current_user.id,
            len(missing_file_ids),
        )
        raise HTTPException(status_code=403, detail="鏃犳潈浣跨敤閮ㄥ垎涓婁紶鏂囦欢")


async def filter_extractable_file_ids(
    db: AsyncSession,
    current_user: User,
    file_ids: List[str],
) -> List[str]:
    if not file_ids:
        return []

    stmt = select(ChatUploadedFile.file_id, ChatUploadedFile.content_type).where(
        ChatUploadedFile.user_id == current_user.id,
        ChatUploadedFile.file_id.in_(file_ids),
    )
    result = await db.execute(stmt)
    content_types = {
        file_id: (content_type or '').lower()
        for file_id, content_type in result.all()
    }
    return [
        file_id
        for file_id in file_ids
        if not content_types.get(file_id, '').startswith('image/')
    ]


def is_image_attachment(uploaded_file: UploadFile) -> bool:
    suffix = Path(uploaded_file.filename or '').suffix.lower()
    content_type = (uploaded_file.content_type or '').lower()
    return content_type.startswith('image/') or suffix in {'.png', '.jpg', '.jpeg', '.webp'}


def build_image_data_url(uploaded_file: UploadFile, contents: bytes) -> str:
    content_type = (uploaded_file.content_type or '').lower()
    if not content_type.startswith('image/'):
        content_type = 'image/jpeg'
    encoded_contents = base64.b64encode(contents).decode('ascii')
    return f'data:{content_type};base64,{encoded_contents}'


async def record_uploaded_chat_files(
    db: AsyncSession,
    current_user: User,
    uploaded_files: List[UploadFile],
    attachment_payloads: List[tuple[str, bytes]],
    uploaded_file_ids: List[str],
) -> None:
    records: List[ChatUploadedFile] = []
    for uploaded_file, (_, contents), file_id in zip(
        uploaded_files,
        attachment_payloads,
        uploaded_file_ids,
    ):
        records.append(
            ChatUploadedFile(
                user_id=current_user.id,
                file_id=file_id,
                file_name=uploaded_file.filename or "attachment",
                content_type=uploaded_file.content_type or "application/octet-stream",
                size=len(contents),
            )
        )

    if records:
        db.add_all(records)
        await db.commit()


def is_supported_attachment(uploaded_file: UploadFile) -> bool:
    suffix = Path(uploaded_file.filename or "").suffix.lower()
    if suffix in ALLOWED_ATTACHMENT_EXTENSIONS:
        return True

    content_type = (uploaded_file.content_type or "").lower()
    return content_type.startswith("image/") or content_type in ALLOWED_ATTACHMENT_MIME_TYPES


def _has_supported_file_signature(uploaded_file: UploadFile, contents: bytes) -> bool:
    suffix = Path(uploaded_file.filename or "").suffix.lower()
    content_type = (uploaded_file.content_type or "").lower()

    if suffix == ".pdf" or content_type == "application/pdf":
        return contents.startswith(b"%PDF-")

    if suffix in {".png", ".jpg", ".jpeg", ".webp"} or content_type.startswith("image/"):
        return (
            contents.startswith(b"\x89PNG\r\n\x1a\n")
            or contents.startswith(b"\xff\xd8\xff")
            or (
                contents.startswith(b"RIFF")
                and len(contents) >= 12
                and contents[8:12] == b"WEBP"
            )
        )

    return False


async def build_attachment_payloads(uploaded_files: List[UploadFile]) -> List[tuple[str, bytes]]:
    if len(uploaded_files) > MAX_ATTACHMENT_FILES:
        raise HTTPException(
            status_code=400,
            detail=f"At most {MAX_ATTACHMENT_FILES} files can be uploaded",
        )

    attachment_payloads: List[tuple[str, bytes]] = []
    for uploaded_file in uploaded_files:
        if not is_supported_attachment(uploaded_file):
            raise HTTPException(status_code=400, detail="浠呮敮鎸佷笂浼犲浘鐗囨垨 PDF 鏂囦欢")

        contents = await uploaded_file.read()
        if len(contents) > MAX_UPLOAD_SIZE:
            raise HTTPException(status_code=413, detail="A single file exceeds the 10MB limit")

        if not _has_supported_file_signature(uploaded_file, contents):
            raise HTTPException(status_code=400, detail="鏂囦欢绫诲瀷涓庡唴瀹逛笉鍖归厤")

        if uploaded_file.content_type and uploaded_file.content_type.startswith("image/"):
            contents = strip_image_exif(contents)
        attachment_payloads.append((uploaded_file.filename or "attachment", contents))

    return attachment_payloads


async def resolve_user_case_context(auth_header: Optional[str]) -> Optional[str]:
    return await _resolve_user_case_context(auth_header, None)


async def _resolve_user_case_context(
    auth_header: Optional[str],
    consultation_profile_id: Optional[int],
) -> Optional[str]:
    if not auth_header or not auth_header.startswith("Bearer "):
        return None

    token = auth_header.replace("Bearer ", "", 1).strip()
    if not token:
        return None

    payload = decode_access_token(token)
    if not payload:
        return None

    user_id = payload.get("sub")
    if not user_id:
        return None

    try:
        async with AsyncSessionLocal() as db:
            if consultation_profile_id is not None:
                if consultation_profile_id <= 0:
                    return None
                return await consultations.build_profile_case_context(
                    db,
                    int(user_id),
                    consultation_profile_id,
                )
            return await consultations.build_user_case_context(db, int(user_id))
    except Exception:
        return None

@app.post("/api/chat")
async def chat_endpoint(
    request: Request,
    mode: str = Form(...),
    message: str = Form(...),
    history: Optional[str] = Form(None),
    thinking: Optional[str] = Form(None),
    context_file_ids: Optional[str] = Form(None),
    consultation_profile_id: Optional[int] = Form(None),
    session_id: Optional[int] = Form(None),
    terminal: Optional[str] = Form(None),
    files: Optional[List[UploadFile]] = File(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    event_terminal = terminal if terminal in {"web", "app"} else "web"
    auth_header = request.headers.get("Authorization")
    parsed_history = parse_history_payload(history)
    is_thinking = parse_bool_payload(thinking)
    existing_file_ids = parse_string_list_payload(context_file_ids)
    uploaded_files = files or []
    await ensure_chat_session_access(db, current_user, session_id)
    await ensure_chat_file_access(db, current_user, existing_file_ids)
    extractable_existing_file_ids = await filter_extractable_file_ids(
        db,
        current_user,
        existing_file_ids,
    )
    user_case_context = await _resolve_user_case_context(
        auth_header,
        consultation_profile_id,
    )

    # Load conversation history from memory if session_id is provided
    if session_id is not None:
        try:
            memory_manager = get_memory_manager(AsyncSessionLocal)
            memory_history = await memory_manager.get_history(session_id, current_user.id)
            if memory_history:
                memory_merged = list(memory_history)
                if parsed_history:
                    seen_contents = {(m["role"], m["content"]) for m in memory_merged}
                    for h in parsed_history:
                        key = (h["role"], h["content"])
                        if key not in seen_contents:
                            memory_merged.append(h)
                            seen_contents.add(key)
                parsed_history = memory_merged
        except Exception as e:
            logger.warning(f"Failed to load memory history for session {session_id}: {e}")

    attachment_payloads = await build_attachment_payloads(uploaded_files)
    extractable_files = [
        (uploaded_file, payload)
        for uploaded_file, payload in zip(uploaded_files, attachment_payloads)
        if not is_image_attachment(uploaded_file)
    ]
    extractable_uploaded_files = [uploaded_file for uploaded_file, _ in extractable_files]
    extractable_payloads = [payload for _, payload in extractable_files]
    image_data_urls = [
        build_image_data_url(uploaded_file, contents)
        for uploaded_file, (_, contents) in zip(uploaded_files, attachment_payloads)
        if is_image_attachment(uploaded_file)
    ]
    uploaded_file_ids = await upload_files_for_extraction(extractable_payloads) if extractable_payloads else []
    await record_uploaded_chat_files(
        db,
        current_user,
        extractable_uploaded_files,
        extractable_payloads,
        uploaded_file_ids,
    )
    file_ids = list(dict.fromkeys([*extractable_existing_file_ids, *uploaded_file_ids]))

    async def event_generator():
        full_response = ""
        label_content_id = new_content_id()
        health_report_request = should_handle_health_report(
            message,
            mode=mode,
            has_attachments=bool(file_ids or image_data_urls),
        )
        latest_metric_request = should_handle_latest_metric(
            message,
            mode=mode,
            has_attachments=bool(file_ids or image_data_urls),
        )
        safety_decision = check_input(message, parsed_history, scope=mode)
        if safety_decision.blocked:
            reply = safety_decision.reply_template or REPLIES["default"]
            yield {"data": json.dumps({"type": "safety", "phase": "input", "action": safety_decision.action, "intent": safety_decision.intent_code, "riskLevel": safety_decision.risk_level, "decisionId": safety_decision.decision_id}, ensure_ascii=False)}
            yield {"data": json.dumps({"type": "content", "content": reply}, ensure_ascii=False)}
            yield {"data": json.dumps({"type": "ai_label", "meta": build_ai_label_meta(content_id=label_content_id)}, ensure_ascii=False)}
            yield {"data": "[DONE]"}
            try:
                async with AsyncSessionLocal() as safety_db:
                    await record_event(safety_db, user_id=current_user.id, terminal=event_terminal, scene=f"chat_{mode}", text=message, decision=safety_decision, reply_text=reply, session_id=session_id)
            except Exception as error:
                logger.warning(f"Failed to record input safety event: {error}")
            return
        # Step 1: Check HighFreqQuestion for exact or partial match if no files/history
        if health_report_request is None and latest_metric_request is None and not file_ids and not parsed_history:
            try:
                async with AsyncSessionLocal() as db:
                    stmt = select(HighFreqQuestion).where(
                        HighFreqQuestion.status == "published",
                        HighFreqQuestion.question == message.strip()
                    )
                    result = await db.execute(stmt)
                    hf_question = result.scalars().first()
                    
                    if hf_question:
                        # Template variable replacement logic
                        answer = hf_question.answer_template
                        
                        if auth_header and auth_header.startswith("Bearer "):
                            token = auth_header.replace("Bearer ", "", 1).strip()
                            if token:
                                payload = decode_access_token(token)
                                if payload and payload.get("sub"):
                                    user_id = int(payload.get("sub"))
                                    
                                    # Get profile to replace variables
                                    if consultation_profile_id is not None:
                                        p_stmt = select(PatientProfile).where(
                                            PatientProfile.id == consultation_profile_id,
                                            PatientProfile.user_id == user_id
                                        )
                                        p_result = await db.execute(p_stmt)
                                        profile = p_result.scalars().first()
                                        
                                        if profile:
                                            answer = answer.replace("[濮撳悕]", profile.name)
                                            answer = answer.replace("[鎬у埆]", profile.gender)
                                            answer = answer.replace("[骞撮緞]", str(profile.age))
                        
                        # High-frequency templates are still subject to output safety checks.
                        template_decision = check_output(answer, scope=mode)
                        if template_decision.blocked:
                            answer = template_decision.reply_template or REPLIES["default"]
                        yield {"data": json.dumps({"type": "content", "content": answer}, ensure_ascii=False)}
                        yield {
                            "data": json.dumps(
                                {"type": "ai_label", "meta": build_ai_label_meta(content_id=label_content_id)},
                                ensure_ascii=False,
                            )
                        }
                        yield {"data": "[DONE]"}
                        
                        # Background task to increment click_count could be added here
                        hf_question.click_count += 1
                        await db.commit()
                        
                        return
            except Exception as e:
                logger.error(f"Error checking high freq questions: {e}")

        try:
            if file_ids:
                yield {
                    "data": json.dumps(
                        {
                            "type": "context",
                            "fileIds": file_ids,
                            "newFileIds": uploaded_file_ids,
                        },
                        ensure_ascii=False,
                    )
                }
            if latest_metric_request is not None:
                reply = await build_latest_metric_response(current_user.id, latest_metric_request)
                output_decision = check_output(reply, scope=mode)
                if output_decision.blocked:
                    reply = output_decision.reply_template or REPLIES["default"]
                full_response = reply
                yield {"data": json.dumps({"type": "content", "content": reply}, ensure_ascii=False)}
            elif health_report_request is not None:
                health_facts = await build_health_report_facts(
                    current_user.id,
                    health_report_request,
                )
                async for chunk in stream_health_report(
                    parsed_history,
                    message,
                    health_facts,
                    thinking=is_thinking,
                ):
                    if isinstance(chunk, dict) and chunk.get("type") == "content":
                        candidate = full_response + chunk.get("content", "")
                        output_decision = check_output(candidate, scope=mode)
                        if output_decision.blocked:
                            reply = output_decision.reply_template or REPLIES["default"]
                            yield {"data": json.dumps({"type": "safety", "phase": "output", "action": output_decision.action, "intent": output_decision.intent_code, "riskLevel": output_decision.risk_level, "decisionId": output_decision.decision_id, "aborted": True}, ensure_ascii=False)}
                            yield {"data": json.dumps({"type": "notice", "level": "warning", "text": "为保障回答安全，本次回答已停止，请咨询专业医生。", "decisionId": output_decision.decision_id}, ensure_ascii=False)}
                            yield {"data": json.dumps({"type": "content", "content": reply}, ensure_ascii=False)}
                            full_response = reply
                            try:
                                async with AsyncSessionLocal() as safety_db:
                                    await record_event(safety_db, user_id=current_user.id, terminal=event_terminal, scene="chat_health_report", text=candidate, decision=output_decision, reply_text=reply, session_id=session_id)
                            except Exception as error:
                                logger.warning(f"Failed to record output safety event: {error}")
                            break
                        full_response = candidate
                        yield {"data": json.dumps(chunk, ensure_ascii=False)}
                    else:
                        yield {"data": json.dumps(chunk, ensure_ascii=False)}
            elif mode == "medical":
                async for chunk in stream_medical_chat(
                    parsed_history,
                    message,
                    thinking=is_thinking,
                    file_ids=file_ids,
                    user_context=user_case_context,
                    image_data_urls=image_data_urls,
                ):
                    if isinstance(chunk, dict) and chunk.get("type") == "content":
                        candidate = full_response + chunk.get("content", "")
                        output_decision = check_output(candidate, scope=mode)
                        if output_decision.blocked:
                            reply = output_decision.reply_template or REPLIES["default"]
                            yield {"data": json.dumps({"type": "safety", "phase": "output", "action": output_decision.action, "intent": output_decision.intent_code, "riskLevel": output_decision.risk_level, "decisionId": output_decision.decision_id, "aborted": True}, ensure_ascii=False)}
                            yield {"data": json.dumps({"type": "notice", "level": "warning", "text": "为保障回答安全，本次回答已停止，请咨询专业医生。", "decisionId": output_decision.decision_id}, ensure_ascii=False)}
                            yield {"data": json.dumps({"type": "content", "content": reply}, ensure_ascii=False)}
                            full_response = reply
                            try:
                                async with AsyncSessionLocal() as safety_db:
                                    await record_event(safety_db, user_id=current_user.id, terminal=event_terminal, scene=f"chat_{mode}", text=candidate, decision=output_decision, reply_text=reply, session_id=session_id)
                            except Exception as error:
                                logger.warning(f"Failed to record output safety event: {error}")
                            break
                        full_response = candidate
                        yield {"data": json.dumps(chunk, ensure_ascii=False)}
                    else:
                        yield {"data": json.dumps(chunk, ensure_ascii=False)}
            else:
                async for chunk in stream_normal_chat(
                    parsed_history,
                    message,
                    thinking=is_thinking,
                    file_ids=file_ids,
                    user_context=user_case_context,
                    image_data_urls=image_data_urls,
                ):
                    if isinstance(chunk, dict) and chunk.get("type") == "content":
                        candidate = full_response + chunk.get("content", "")
                        output_decision = check_output(candidate, scope=mode)
                        if output_decision.blocked:
                            reply = output_decision.reply_template or REPLIES["default"]
                            yield {"data": json.dumps({"type": "safety", "phase": "output", "action": output_decision.action, "intent": output_decision.intent_code, "riskLevel": output_decision.risk_level, "decisionId": output_decision.decision_id, "aborted": True}, ensure_ascii=False)}
                            yield {"data": json.dumps({"type": "notice", "level": "warning", "text": "为保障回答安全，本次回答已停止，请咨询专业医生。", "decisionId": output_decision.decision_id}, ensure_ascii=False)}
                            yield {"data": json.dumps({"type": "content", "content": reply}, ensure_ascii=False)}
                            full_response = reply
                            try:
                                async with AsyncSessionLocal() as safety_db:
                                    await record_event(safety_db, user_id=current_user.id, terminal=event_terminal, scene=f"chat_{mode}", text=candidate, decision=output_decision, reply_text=reply, session_id=session_id)
                            except Exception as error:
                                logger.warning(f"Failed to record output safety event: {error}")
                            break
                        full_response = candidate
                        yield {"data": json.dumps(chunk, ensure_ascii=False)}
                    else:
                        yield {"data": json.dumps(chunk, ensure_ascii=False)}
            yield {
                "data": json.dumps(
                    {"type": "ai_label", "meta": build_ai_label_meta(content_id=label_content_id)},
                    ensure_ascii=False,
                )
            }
            yield {"data": "[DONE]"}
        except Exception as e:
            yield {"data": json.dumps({"error": str(e)})}
            yield {"data": "[DONE]"}
            full_response = ""

        # Persist conversation to memory system
        if session_id is not None and full_response:
            try:
                memory_manager = get_memory_manager(AsyncSessionLocal)
                await memory_manager.add_turn(session_id, current_user.id, message, full_response)
            except Exception as e:
                logger.error(f"Failed to persist memory for session {session_id}: {e}")

    return EventSourceResponse(event_generator())


@app.post("/api/chat/polish")
async def polish_text_endpoint(
    request: Request,
    _current_user: User = Depends(get_current_user),
):
    from pydantic import BaseModel

    class PolishRequest(BaseModel):
        text: str

    try:
        body = await request.json()
        polish_request = PolishRequest(**body)
    except Exception:
        raise HTTPException(status_code=400, detail="璇锋眰鍙傛暟鏃犳晥锛岃鎻愪緵寰呮鼎鑹茬殑鏂囨湰鍐呭")

    original_text = polish_request.text.strip()
    if not original_text:
        raise HTTPException(status_code=400, detail="娑﹁壊鍐呭涓嶈兘涓虹┖")

    try:
        polished_text = await polish_medical_query(original_text)
        return {"original": original_text, "polished": polished_text}
    except Exception as e:
        logger.error(f"娑﹁壊鎺ュ彛寮傚父: {e}")
        raise HTTPException(status_code=500, detail="AI polish service is temporarily unavailable")


@app.post("/api/chat/uploads")
async def upload_chat_attachments(
    files: List[UploadFile] = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    attachment_payloads = await build_attachment_payloads(files)
    uploaded_file_ids = await upload_files_for_extraction(attachment_payloads)
    await record_uploaded_chat_files(
        db,
        current_user,
        files,
        attachment_payloads,
        uploaded_file_ids,
    )
    return {
        "files": [
            {
                "file_id": file_id,
                "file_name": uploaded_file.filename or "attachment",
                "content_type": uploaded_file.content_type or "application/octet-stream",
                "size": len(contents),
            }
            for (uploaded_file, (_, contents), file_id) in zip(
                files,
                attachment_payloads,
                uploaded_file_ids,
            )
        ]
    }

@app.post("/api/upload")
async def upload_image(
    file: UploadFile = File(...),
    _current_user: User = Depends(get_current_user),
):
    """
    Upload an image. If it's an image, strip its EXIF data for privacy.
    Returns the stripped image directly for testing/development.
    """
    contents = await file.read()
    
    if file.content_type and file.content_type.startswith("image/"):
        contents = strip_image_exif(contents)
        
    return Response(content=contents, media_type=file.content_type or "image/jpeg")

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

