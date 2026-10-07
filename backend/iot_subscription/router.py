"""
IoT 平台 HTTP 订阅推送接口

实现智慧物联网云平台的数据订阅接收功能：
1. GET  /api/iot/subscribe - URL 验证端点
2. POST /api/iot/subscribe - 数据接收端点

支持 6 种推送数据类型：
- 设备事件订阅
- 报警记录确认处置
- 故障工单确认处置
- 故障工单创建
- 设备信息变更（增删改）
- 设备状态变更
"""
import asyncio
import hashlib
import hmac
import os
import time
from pathlib import Path

from fastapi import APIRouter, Query, Request
from fastapi.responses import PlainTextResponse, JSONResponse
from loguru import logger

from iot_subscription.database import (
    close_pool,
    get_connection,
    init_pool,
    is_bound_device_for_ingest,
    process_event,
)
from iot_subscription.rotating_writer import RotatingLogWriter


# ========== 轮转日志写入 ==========
# 日志根目录：backend/logs/app_upload/
_upload_log_dir = Path(__file__).parent.parent / "logs" / "app_upload"
log_writer = RotatingLogWriter(root_dir=_upload_log_dir)


def write_push_log(tag: str, data: dict) -> None:
    """将推送数据写入轮转日志文件"""
    log_writer.write_json_record(tag, data)


router = APIRouter(prefix="/api/iot", tags=["iot_subscription"])


# ========== 配置 ==========
# 用户自定义 token，需与物联网云平台配置页面中的 token 保持一致
IOT_SUBSCRIBE_TOKEN = os.getenv("IOT_SUBSCRIBE_TOKEN", "").strip()
IOT_SIGNATURE_WINDOW_SECONDS = int(os.getenv("IOT_SIGNATURE_WINDOW_SECONDS", "300"))
_seen_nonces: dict[str, float] = {}


def _is_production_env() -> bool:
    return os.getenv("APP_ENV", os.getenv("ENVIRONMENT", "")).strip().lower() in {
        "prod",
        "production",
    }


if _is_production_env() and not IOT_SUBSCRIBE_TOKEN:
    raise RuntimeError("IOT_SUBSCRIBE_TOKEN must be configured in production")


# ========== 签名验证 ==========

def verify_signature(signature: str, timestamp: str, nonce: str, token: str) -> bool:
    """
    验证平台推送的签名

    算法：
    1. 将 token, timestamp, nonce 按字典序排序
    2. 拼接成字符串
    3. MD5 加密
    4. 与 signature 对比（大写）
    """
    if not all([signature, timestamp, nonce]):
        return False

    # 按字典序排序
    params = sorted([token, timestamp, nonce])
    # 拼接
    content = "".join(params)
    # MD5 加密
    md5_hash = hashlib.md5(content.encode("utf-8")).hexdigest().upper()

    return hmac.compare_digest(md5_hash, signature.upper())


def is_fresh_timestamp(timestamp: str) -> bool:
    try:
        timestamp_value = int(timestamp)
    except (TypeError, ValueError):
        return False

    if timestamp_value > 10_000_000_000:
        timestamp_value = timestamp_value // 1000

    return abs(int(time.time()) - timestamp_value) <= IOT_SIGNATURE_WINDOW_SECONDS


def mark_nonce_once(signature: str, timestamp: str, nonce: str) -> bool:
    now = time.time()
    expired_before = now - IOT_SIGNATURE_WINDOW_SECONDS
    for key, seen_at in list(_seen_nonces.items()):
        if seen_at < expired_before:
            _seen_nonces.pop(key, None)

    nonce_key = f"{timestamp}:{nonce}:{signature}"
    if nonce_key in _seen_nonces:
        return False
    _seen_nonces[nonce_key] = now
    return True


def verify_request_signature(signature: str, timestamp: str, nonce: str) -> bool:
    if not IOT_SUBSCRIBE_TOKEN:
        logger.error("IOT_SUBSCRIBE_TOKEN is not configured")
        return False

    if not is_fresh_timestamp(timestamp):
        return False

    if not verify_signature(signature, timestamp, nonce, IOT_SUBSCRIBE_TOKEN):
        return False

    return mark_nonce_once(signature, timestamp, nonce)


# ========== 接口实现 ==========

@router.get("/subscribe", summary="IoT平台URL验证")
async def verify_url(
    nonce: str = Query(..., description="随机数"),
    signature: str = Query(..., description="签名"),
    timestamp: str = Query(..., description="时间戳"),
):
    """
    URL 验证端点

    平台配置 URL 后发起 GET 请求验证，验证通过后返回 nonce 值。
    """
    logger.info(f"IoT URL验证请求: nonce={nonce}, timestamp={timestamp}")

    # 验证签名
    if verify_request_signature(signature, timestamp, nonce):
        logger.info("IoT URL验证成功")
        return PlainTextResponse(content=nonce)
    else:
        logger.warning("IoT URL验证失败: 签名不匹配")
        return PlainTextResponse(content="error", status_code=403)


@router.post("/subscribe", summary="IoT平台数据接收")
async def receive_push_data(request: Request):
    """
    数据接收端点

    接收平台推送的各类数据，立即写入本地文件。
    后续解析和入库由文件监听服务负责，避免数据库处理影响平台回调成功率。
    """
    try:
        api_received_ms = round(time.time() * 1000, 3)
        body = await request.json()
        if not isinstance(body, dict):
            logger.warning("IoT 推送数据格式异常: body 不是 JSON 对象")
            return JSONResponse(content={"error": "body must be a JSON object"}, status_code=400)

        # 外部平台回调入口：不强制签名/token 认证，验签仅在有参数时记录日志
        signature = request.query_params.get("signature") or request.headers.get("signature", "")
        timestamp = request.query_params.get("timestamp") or request.headers.get("timestamp", "")
        nonce = request.query_params.get("nonce") or request.headers.get("nonce", "")
        if signature or timestamp or nonce:
            if verify_request_signature(signature, timestamp, nonce):
                logger.info("IoT 推送签名验证成功")
            else:
                logger.warning("IoT 推送签名验证失败（不拦截，继续处理）")
        else:
            logger.info("IoT 推送未携带签名参数，直接接收")

        perf = body.get("_perf")
        if isinstance(perf, dict):
            perf["api_received_ms"] = api_received_ms
        logger.info(f"IoT 收到推送数据: {body}")

        imei = body.get("imei")
        if imei:
            allowed = await asyncio.to_thread(is_bound_device_for_ingest, imei)
            if not allowed:
                logger.warning(f"IoT 忽略未绑定或未知设备上报: imei={imei}")
                return PlainTextResponse(content="success")

        write_push_log("RAW", body)
        return PlainTextResponse(content="success")

    except Exception as e:
        logger.error(f"IoT 推送数据落盘异常: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)


async def handle_device_event(data: dict) -> None:
    """处理设备事件订阅推送，写入数据库"""
    imei = data.get("imei")
    event_name = data.get("eventName")
    device_state = data.get("deviceState")
    items = data.get("items", [])

    logger.info(
        f"设备事件: imei={imei}, event={event_name}, "
        f"state={device_state}, items_count={len(items)}"
    )

    def _write_db():
        with get_connection() as conn:
            return process_event(conn, data)

    processed = await asyncio.to_thread(_write_db)
    if processed is not None:
        logger.info(f"设备事件已入库或同步: imei={imei}")
    else:
        logger.info(f"事件已存在，跳过: imei={imei}")


async def handle_alarm_confirm(data: dict) -> None:
    """处理报警记录确认处置推送"""
    uuid = data.get("uuid")
    imei = data.get("imei")
    alarm_reason = data.get("alarmReason")
    handler = data.get("handler")

    logger.info(
        f"报警确认: uuid={uuid}, imei={imei}, "
        f"reason={alarm_reason}, handler={handler}"
    )
    # TODO: 在此添加业务逻辑


async def handle_fault_order_confirm(data: dict) -> None:
    """处理故障工单确认处置推送"""
    uuid = data.get("uuid")
    imei = data.get("imei")
    status = data.get("status")

    logger.info(f"故障工单确认: uuid={uuid}, imei={imei}, status={status}")
    # TODO: 在此添加业务逻辑


async def handle_fault_order_create(data: dict) -> None:
    """处理故障工单创建推送"""
    uuid = data.get("uuid")
    imei = data.get("imei")
    fault_type = data.get("type")
    description = data.get("description")

    logger.info(
        f"故障工单创建: uuid={uuid}, imei={imei}, "
        f"type={fault_type}, desc={description}"
    )
    # TODO: 在此添加业务逻辑


async def handle_device_change(data: dict) -> None:
    """处理设备信息变更（增删改）推送"""
    action = data.get("action")
    devices = data.get("devices", [])

    logger.info(f"设备信息变更: action={action}, devices_count={len(devices)}")

    def _write_db():
        with get_connection() as conn:
            for dev in devices:
                imei = dev.get("deviceImei")
                if not imei:
                    continue
                if action == "create":
                    conn.execute("""
                        INSERT INTO iot_devices (imei, device_type, device_version, site,
                            longitude, latitude, company_name)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                        ON CONFLICT (imei) DO NOTHING
                    """, (imei, dev.get("deviceTypeName"), dev.get("deviceModel"),
                          dev.get("installAddress") or dev.get("detailedAddress"),
                          dev.get("longitude"), dev.get("latitude"),
                          dev.get("companyName")))
                elif action == "update":
                    conn.execute("""
                        UPDATE iot_devices SET
                            device_type = COALESCE(%s, device_type),
                            device_version = COALESCE(%s, device_version),
                            site = COALESCE(%s, site),
                            longitude = COALESCE(%s, longitude),
                            latitude = COALESCE(%s, latitude),
                            company_name = COALESCE(%s, company_name),
                            updated_at = CURRENT_TIMESTAMP
                        WHERE imei = %s
                    """, (dev.get("deviceTypeName"), dev.get("deviceModel"),
                          dev.get("installAddress") or dev.get("detailedAddress"),
                          dev.get("longitude"), dev.get("latitude"),
                          dev.get("companyName"), imei))
                elif action == "delete":
                    # 级联删除: classified items/events → latest metrics → contacts → device
                    conn.execute("DELETE FROM iot_health_event_items WHERE imei = %s", (imei,))
                    conn.execute("DELETE FROM iot_alarm_event_items WHERE imei = %s", (imei,))
                    conn.execute("DELETE FROM iot_heartbeat_event_items WHERE imei = %s", (imei,))
                    conn.execute("DELETE FROM iot_device_latest_metrics WHERE imei = %s", (imei,))
                    conn.execute("DELETE FROM iot_health_events WHERE imei = %s", (imei,))
                    conn.execute("DELETE FROM iot_alarm_events WHERE imei = %s", (imei,))
                    conn.execute("DELETE FROM iot_heartbeat_events WHERE imei = %s", (imei,))
                    conn.execute("DELETE FROM iot_device_contacts WHERE imei = %s", (imei,))
                    conn.execute("DELETE FROM iot_devices WHERE imei = %s", (imei,))
                    logger.info(f"设备已级联删除: imei={imei}")

    await asyncio.to_thread(_write_db)


async def handle_device_state_change(data: dict) -> None:
    """处理设备状态变更推送，更新设备状态"""
    devices = data.get("devices", [])

    logger.info(f"设备状态变更: devices_count={len(devices)}")
    for device in devices:
        imei = device.get("deviceImei")
        state = device.get("state")
        op_name = device.get("operationName")
        logger.info(f"  设备: imei={imei}, state={state}, op={op_name}")

    def _write_db():
        with get_connection() as conn:
            for device in devices:
                imei = device.get("deviceImei")
                state = device.get("state")
                if imei and state is not None:
                    # 状态映射: 0:复位->0(正常), 4:取消停用->0, 6:停用->4(离线)
                    state_map = {"0": 0, "4": 0, "6": 4}
                    db_state = state_map.get(str(state), 0)
                    conn.execute("""
                        UPDATE iot_devices SET device_state = %s, updated_at = CURRENT_TIMESTAMP
                        WHERE imei = %s
                    """, (db_state, imei))

    await asyncio.to_thread(_write_db)
