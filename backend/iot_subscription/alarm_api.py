"""
IoT 报警信息接口

提供单设备报警信息查询、设备信息查询等功能
"""
import asyncio
import re
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
from loguru import logger

from dependencies import get_current_user
from models import User
from iot_subscription.auth import current_iot_user_id, ensure_device_access
from iot_subscription.database import get_connection


router = APIRouter(prefix="/api/iot", tags=["iot_alarm_api"])


# ========== 请求/响应模型 ==========

class AlarmQueryRequest(BaseModel):
    """报警信息查询请求"""
    deviceImei: str = Field(..., description="设备IMEI", min_length=14, max_length=16)
    handlerStatus: Optional[int] = Field(None, description="处理状态 0:未处理 1:已处理，不传则查询全部", ge=0, le=1)
    eventStartDate: Optional[str] = Field(None, description="事件开始日期 YYYY-MM-DD，不传默认当天")
    eventEndDate: Optional[str] = Field(None, description="事件结束日期 YYYY-MM-DD，不传默认当天")

    @field_validator("deviceImei")
    @classmethod
    def validate_imei(cls, v: str) -> str:
        if not re.match(r"^\d{14,16}$", v):
            raise ValueError("IMEI必须是14-16位数字")
        return v

    @field_validator("eventStartDate", "eventEndDate")
    @classmethod
    def validate_date(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return None
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError:
            raise ValueError("日期格式必须为 YYYY-MM-DD")
        return v


class DeviceGetRequest(BaseModel):
    """设备信息查询请求"""
    deviceImei: str = Field(..., description="设备IMEI", min_length=14, max_length=16)

    @field_validator("deviceImei")
    @classmethod
    def validate_imei(cls, v: str) -> str:
        if not re.match(r"^\d{14,16}$", v):
            raise ValueError("IMEI必须是14-16位数字")
        return v


class ApiResponse(BaseModel):
    """统一API响应"""
    code: str = "OK"
    success: bool = True
    message: Optional[dict] = None


# ========== 接口实现 ==========

@router.post("/devices/alarm", summary="获取单设备报警信息")
async def get_device_alarm(
    req: AlarmQueryRequest,
    current_user: User = Depends(get_current_user),
):
    """
    获取单设备报警信息接口

    根据设备IMEI、处理状态、日期范围查询报警信息
    """
    today = datetime.now().strftime("%Y-%m-%d")
    event_start_date = req.eventStartDate or req.eventEndDate or today
    event_end_date = req.eventEndDate or req.eventStartDate or today

    logger.info(f"查询设备报警: imei={req.deviceImei}, status={req.handlerStatus}, "
                f"date={event_start_date}~{event_end_date}")

    def _query_alarm():
        with get_connection() as conn:
            ensure_device_access(conn, current_iot_user_id(current_user), req.deviceImei)
            # 1. 查询设备基本信息
            result = conn.execute("""
                SELECT id, device_type, room_name
                FROM iot_devices
                WHERE imei = %s
            """, (req.deviceImei,))
            device_row = result.fetchone()

            if not device_row:
                return None

            device_id, device_type, room_name = device_row

            # 2. 构建查询条件
            base_sql = """
                SELECT id, event_name, data_type, handler_status,
                       handle_time, alarm_reason, sign_time
                FROM iot_alarm_events
                WHERE imei = %s
                  AND sign_time >= %s::DATE
                  AND sign_time < (%s::DATE + INTERVAL '1 day')
            """
            params = [req.deviceImei, event_start_date, event_end_date]

            # 添加处理状态过滤
            if req.handlerStatus is not None:
                base_sql += " AND handler_status = %s"
                params.append(req.handlerStatus)

            base_sql += " ORDER BY sign_time DESC, id DESC"

            # 3. 查询报警事件
            result = conn.execute(base_sql, params)
            event_rows = result.fetchall()

            # 4. 组装事件列表
            events = []
            for row in event_rows:
                event_id, event_name, data_type, handler_status, handle_time, alarm_reason, sign_time = row

                event_info = {
                    "eventName": event_name or "",
                    "data_type": data_type,
                    "handlerStatus": handler_status,
                    "handlerTime": handle_time.strftime("%Y-%m-%d %H:%M") if handle_time else None,
                    "alarmReason": alarm_reason or "",
                    "reportDate": sign_time.strftime("%Y-%m-%d %H:%M") if sign_time else None,
                }
                events.append(event_info)

            # 5. 组装返回数据
            return {
                "deviceId": device_id,
                "deviceImei": req.deviceImei,
                "deviceType": device_type,
                "roomName": room_name,
                "events": events,
            }

    try:
        data = await asyncio.to_thread(_query_alarm)
        if data is None:
            return ApiResponse(
                code="ERROR",
                success=False,
                message={"msg": "设备不存在"}
            )
        return ApiResponse(
            code="OK",
            success=True,
            message={"data": data}
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except Exception as e:
        logger.error(f"查询设备报警失败: {e}")
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": f"查询失败: {str(e)}"}
        )


@router.post("/device/get", summary="获取设备信息")
async def get_device_info(
    req: DeviceGetRequest,
    current_user: User = Depends(get_current_user),
):
    """
    获取设备信息接口

    根据设备IMEI查询设备详细信息、最新状态和属性
    """
    logger.info(f"查询设备信息: imei={req.deviceImei}")

    def _query_device():
        with get_connection() as conn:
            ensure_device_access(conn, current_iot_user_id(current_user), req.deviceImei)
            # 1. 查询设备基本信息
            result = conn.execute("""
                SELECT id, device_type, device_version, room_name, device_state
                FROM iot_devices
                WHERE imei = %s
            """, (req.deviceImei,))
            device_row = result.fetchone()

            if not device_row:
                return None

            device_id, device_type, device_version, room_name, current_device_state = device_row

            # 2. 查询最新事件（获取状态和上报时间）
            result = conn.execute("""
                SELECT device_state, sign_time
                FROM (
                    (SELECT device_state, sign_time, id, 1 AS source_order
                     FROM iot_alarm_events
                     WHERE imei = %s
                     ORDER BY sign_time DESC NULLS LAST, id DESC
                     LIMIT 1)
                    UNION ALL
                    (SELECT device_state, sign_time, id, 2 AS source_order
                     FROM iot_health_events
                     WHERE imei = %s
                     ORDER BY sign_time DESC NULLS LAST, id DESC
                     LIMIT 1)
                    UNION ALL
                    (SELECT device_state, sign_time, id, 3 AS source_order
                     FROM iot_heartbeat_events
                     WHERE imei = %s
                     ORDER BY sign_time DESC NULLS LAST, id DESC
                     LIMIT 1)
                ) latest_event
                ORDER BY sign_time DESC NULLS LAST, source_order, id DESC
                LIMIT 1
            """, (req.deviceImei, req.deviceImei, req.deviceImei))
            event_row = result.fetchone()

            state_map = {0: "正常", 1: "故障", 2: "报警", 4: "离线", 8: "隐患"}
            if event_row:
                latest_event_state, sign_time = event_row
                state_value = current_device_state if current_device_state is not None else latest_event_state
                state_text = state_map.get(state_value, "未知")
                report_date = sign_time.strftime("%Y-%m-%d %H:%M") if sign_time else None
            else:
                state_text = state_map.get(current_device_state, "未知") if current_device_state is not None else "未知"
                report_date = None

            # 3. 组装返回数据
            return {
                "deviceId": device_id,
                "deviceImei": req.deviceImei,
                "deviceType": device_type,
                "deviceVersion": device_version,
                "state": state_text,
                "roomName": room_name,
                "reportDate": report_date,
            }

    try:
        data = await asyncio.to_thread(_query_device)
        if data is None:
            return ApiResponse(
                code="ERROR",
                success=False,
                message={"msg": "设备不存在"}
            )
        return ApiResponse(
            code="OK",
            success=True,
            message={"data": data}
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except Exception as e:
        logger.error(f"查询设备信息失败: {e}")
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": f"查询失败: {str(e)}"}
        )
