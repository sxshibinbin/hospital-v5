"""
IoT 事件上报信息查询接口

提供单设备心跳事件列表和事件属性明细查询功能。
"""
import asyncio
import re
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from loguru import logger
from pydantic import BaseModel, Field, field_validator

from dependencies import get_current_user
from models import User
from iot_subscription.auth import (
    current_iot_user_id,
    ensure_device_access,
    ensure_event_access,
)
from iot_subscription.database import get_connection


router = APIRouter(prefix="/api/iot", tags=["iot_event_api"])

HEARTBEAT_EVENT_NAMES = (
    "设备存在信息上报",
    "呼吸心率信息上报",
    "异常挣扎信息上报",
    "无人计时状态信息上报",
    "睡眠报告信息上报",
    "睡眠综合状态上报",
)


class DeviceEventsRequest(BaseModel):
    """单设备事件信息查询请求"""
    deviceImei: str = Field(..., description="设备IMEI", min_length=14, max_length=16)
    handlerStatus: Optional[int] = Field(None, description="处理状态 0:未处理 1:已处理，不传则查询全部", ge=0, le=1)
    eventStartDate: str = Field(..., description="事件开始日期 YYYY-MM-DD")
    eventEndDate: str = Field(..., description="事件结束日期 YYYY-MM-DD")

    @field_validator("deviceImei")
    @classmethod
    def validate_imei(cls, v: str) -> str:
        v = v.strip()
        if not re.match(r"^\d{14,16}$", v):
            raise ValueError("IMEI必须是14-16位数字")
        return v

    @field_validator("eventStartDate", "eventEndDate")
    @classmethod
    def validate_date(cls, v: str) -> str:
        if not v:
            raise ValueError("日期不能为空")
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError as exc:
            raise ValueError("日期格式必须为 YYYY-MM-DD") from exc
        return v


class EventInfoRequest(BaseModel):
    """事件明细查询请求"""
    eventId: int = Field(..., description="事件ID", gt=0)


class ApiResponse(BaseModel):
    """统一API响应"""
    code: str = "OK"
    success: bool = True
    message: Optional[dict] = None


def _format_second(value) -> str | None:
    if value is None:
        return None
    if hasattr(value, "strftime"):
        return value.strftime("%Y-%m-%d %H:%M:%S")
    return str(value)


def _format_text(value) -> str:
    return "" if value is None else str(value)


@router.post("/devices/events", summary="获取单设备事件信息")
async def get_device_events(
    req: DeviceEventsRequest,
    current_user: User = Depends(get_current_user),
):
    """根据设备IMEI、处理状态和日期范围查询心跳事件信息。"""
    start_date = datetime.strptime(req.eventStartDate, "%Y-%m-%d").date()
    end_date = datetime.strptime(req.eventEndDate, "%Y-%m-%d").date()
    if start_date > end_date:
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": "事件开始日期不能大于结束日期"},
        )

    logger.info(
        f"查询设备事件: imei={req.deviceImei}, status={req.handlerStatus}, "
        f"date={req.eventStartDate}~{req.eventEndDate}"
    )

    def _query_events():
        with get_connection() as conn:
            ensure_device_access(conn, current_iot_user_id(current_user), req.deviceImei)
            device_row = conn.execute("""
                SELECT id, device_type, COALESCE(room_name, site, '') AS room_name
                FROM iot_devices
                WHERE imei = %s
                LIMIT 1
            """, (req.deviceImei,)).fetchone()

            if not device_row:
                return None

            device_id, device_type, room_name = device_row
            event_name_placeholders = ", ".join(["%s"] * len(HEARTBEAT_EVENT_NAMES))
            event_sql = f"""
                SELECT id, event_name, data_type, sign_time
                FROM iot_heartbeat_events
                WHERE imei = %s
                  AND sign_time >= %s::DATE
                  AND sign_time < (%s::DATE + INTERVAL '1 day')
                  AND event_name IN ({event_name_placeholders})
            """
            params = [
                req.deviceImei,
                req.eventStartDate,
                req.eventEndDate,
                *HEARTBEAT_EVENT_NAMES,
            ]

            if req.handlerStatus is not None:
                event_sql += " AND handler_status = %s"
                params.append(req.handlerStatus)

            event_sql += " ORDER BY sign_time DESC NULLS LAST, id DESC"
            rows = conn.execute(event_sql, params).fetchall()

            event_groups = {}
            for event_id, event_name, data_type, sign_time in rows:
                event_name_text = _format_text(event_name)
                report_date = _format_second(sign_time)

                if event_name_text not in event_groups:
                    event_groups[event_name_text] = {
                        "eventName": event_name_text,
                        "eventCount": 0,
                        "data_type": data_type,
                        "reportDate": report_date,
                        "eventDetails": [],
                    }

                group = event_groups[event_name_text]
                group["eventCount"] += 1
                group["eventDetails"].append({
                    "eventId": event_id,
                    "data_type": data_type,
                    "reportDate": report_date,
                })

            return {
                "deviceId": device_id,
                "deviceImei": req.deviceImei,
                "deviceType": device_type,
                "roomName": room_name,
                "events": list(event_groups.values()),
            }

    try:
        data = await asyncio.to_thread(_query_events)
        if data is None:
            return ApiResponse(
                code="ERROR",
                success=False,
                message={"msg": "设备不存在"},
            )
        return ApiResponse(
            code="OK",
            success=True,
            message={"data": [data]},
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except Exception as e:
        logger.error(f"查询设备事件失败: {e}")
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": f"查询失败: {str(e)}"},
        )


@router.post("/devices/event/infos", summary="获取事件详细信息")
async def get_event_infos(
    req: EventInfoRequest,
    current_user: User = Depends(get_current_user),
):
    """根据心跳事件ID查询事件属性明细。"""
    logger.info(f"查询事件明细: eventId={req.eventId}")

    def _query_infos():
        with get_connection() as conn:
            ensure_event_access(
                conn,
                current_iot_user_id(current_user),
                req.eventId,
                "iot_heartbeat_events",
            )
            event_row = conn.execute("""
                SELECT e.id, d.id AS device_id
                FROM iot_heartbeat_events e
                LEFT JOIN iot_devices d ON d.imei = e.imei
                WHERE e.id = %s
                LIMIT 1
            """, (req.eventId,)).fetchone()

            if not event_row:
                return None

            _, device_id = event_row
            item_rows = conn.execute("""
                SELECT attr_name, attr_value, sign_time
                FROM iot_heartbeat_event_items
                WHERE event_id = %s
                ORDER BY sign_time DESC NULLS LAST, id DESC
            """, (req.eventId,)).fetchall()

            items = [
                {
                    "attr_name": _format_text(attr_name),
                    "attr_value": _format_text(attr_value),
                    "reportDate": _format_second(sign_time),
                }
                for attr_name, attr_value, sign_time in item_rows
            ]

            return {
                "deviceId": device_id,
                "items": items,
            }

    try:
        data = await asyncio.to_thread(_query_infos)
        if data is None:
            return ApiResponse(
                code="ERROR",
                success=False,
                message={"msg": "事件不存在"},
            )
        return ApiResponse(
            code="OK",
            success=True,
            message={"data": [data]},
        )
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except Exception as e:
        logger.error(f"查询事件明细失败: {e}")
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": f"查询失败: {str(e)}"},
        )
