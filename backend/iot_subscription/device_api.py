"""
IoT 设备管理接口

提供设备新增、类型字典查询、检测报告查询等功能
"""
import asyncio
import hashlib
import json
import os
import re
import time
from datetime import date, datetime, timedelta
from typing import Optional

import requests
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator
from loguru import logger

from dependencies import get_current_user
from models import User
from iot_subscription.auth import (
    current_iot_user_id,
    current_operator_name,
    ensure_device_access,
)
from iot_subscription.database import get_connection


router = APIRouter(prefix="/api/iot", tags=["iot_device_api"])

WEARABLE_REPORT_ATTR_NAMES = ("心率", "血氧", "舒张压", "收缩压", "温度", "计步")
SLEEP_RADAR_REPORT_ATTR_NAMES = (
    "体动",
    "心率",
    "呼吸次数",
    "呼吸",
    "呼吸状态",
    "睡眠状态",
    "离床状态",
    "运动状态",
    "存在状态",
)
SLEEP_RADAR_REPORT_DISPLAY_NAMES = {
    "呼吸次数": "呼吸",
    "呼吸状态": "呼吸",
}
SLEEP_RADAR_REPORT_ITEM_ORDER = (
    "体动",
    "心率",
    "呼吸",
    "睡眠状态",
    "离床状态",
    "运动状态",
    "存在状态",
)

METRIC_DEFINITIONS = {
    0: {
        "itemName": "心率",
        "unit": "次/分",
        "thresholds": {"safeLow": 60, "safeHigh": 100},
        "series": [
            {
                "key": "heartRate",
                "name": "心率",
                "attrName": "心率",
                "unit": "次/分",
                "fractionDigits": 0,
            },
        ],
    },
    1: {
        "itemName": "血氧饱和度",
        "unit": "%",
        "thresholds": {"criticalLow": 70, "safeLow": 90, "axisMax": 100},
        "series": [
            {
                "key": "spo2",
                "name": "血氧饱和度",
                "attrName": "血氧",
                "unit": "%",
                "fractionDigits": 0,
            },
        ],
    },
    2: {
        "itemName": "血压",
        "unit": "mmHg",
        "thresholds": {
            "systolic": {"safeLow": 90, "safeHigh": 140},
            "diastolic": {"safeLow": 60, "safeHigh": 90},
        },
        "series": [
            {
                "key": "systolic",
                "name": "高压",
                "attrName": "收缩压",
                "unit": "mmHg",
                "fractionDigits": 0,
            },
            {
                "key": "diastolic",
                "name": "低压",
                "attrName": "舒张压",
                "unit": "mmHg",
                "fractionDigits": 0,
            },
        ],
    },
    3: {
        "itemName": "体温",
        "unit": "℃",
        "thresholds": {"safeLow": 36.0, "safeHigh": 37.3},
        "series": [
            {
                "key": "temperature",
                "name": "体温",
                "attrName": "温度",
                "unit": "℃",
                "fractionDigits": 1,
            },
        ],
    },
    4: {
        "itemName": "步数",
        "unit": "步",
        "thresholds": {},
        "series": [
            {
                "key": "steps",
                "name": "步数",
                "attrName": "计步",
                "unit": "步",
                "fractionDigits": 0,
                "valueMode": "total",
            },
        ],
    },
    5: {
        "itemName": "体动",
        "unit": "",
        "thresholds": {},
        "series": [
            {
                "key": "radarBodyMotion",
                "name": "体动",
                "attrName": "体动",
                "unit": "",
                "fractionDigits": 0,
            },
        ],
    },
    6: {
        "itemName": "呼吸",
        "unit": "次/分",
        "thresholds": {"safeLow": 12, "safeHigh": 20},
        "series": [
            {
                "key": "radarBreath",
                "name": "呼吸",
                "attrNames": ["呼吸", "呼吸次数", "呼吸状态"],
                "unit": "次/分",
                "fractionDigits": 0,
            },
        ],
    },
    7: {
        "itemName": "睡眠状态",
        "unit": "",
        "thresholds": {},
        "series": [
            {
                "key": "radarSleepStatus",
                "name": "睡眠状态",
                "attrName": "睡眠状态",
                "unit": "",
                "fractionDigits": 0,
            },
        ],
    },
    8: {
        "itemName": "离床状态",
        "unit": "",
        "thresholds": {},
        "series": [
            {
                "key": "radarOutOfBedStatus",
                "name": "离床状态",
                "attrName": "离床状态",
                "unit": "",
                "fractionDigits": 0,
            },
        ],
    },
    9: {
        "itemName": "运动状态",
        "unit": "",
        "thresholds": {},
        "series": [
            {
                "key": "radarMotionStatus",
                "name": "运动状态",
                "attrName": "运动状态",
                "unit": "",
                "fractionDigits": 0,
            },
        ],
    },
    10: {
        "itemName": "存在状态",
        "unit": "",
        "thresholds": {},
        "series": [
            {
                "key": "radarPresenceStatus",
                "name": "存在状态",
                "attrName": "存在状态",
                "unit": "",
                "fractionDigits": 0,
            },
        ],
    },
}


# ========== 配置（从环境变量读取） ==========
IOT_PLATFORM_BASE_URL = os.getenv("IOT_PLATFORM_BASE_URL", "https://webapi.nbiotyun.com").strip()
IOT_APP_KEY = os.getenv("IOT_APP_KEY", "").strip()
IOT_APP_SECRET = os.getenv("IOT_APP_SECRET", "").strip()


def _is_production_env() -> bool:
    return os.getenv("APP_ENV", os.getenv("ENVIRONMENT", "")).strip().lower() in {
        "prod",
        "production",
    }


if _is_production_env() and (not IOT_APP_KEY or not IOT_APP_SECRET):
    raise RuntimeError("IOT_APP_KEY and IOT_APP_SECRET must be configured in production")


def _ensure_iot_platform_configured() -> None:
    if not IOT_APP_KEY or not IOT_APP_SECRET:
        raise HTTPException(status_code=503, detail="IoT platform credentials are not configured")


def _mask_secret(value: str) -> str:
    if len(value) <= 4:
        return "***"
    return f"{value[:2]}***{value[-2:]}"


# ========== 请求/响应模型 ==========

class DeviceAddRequest(BaseModel):
    """新增设备请求"""
    deviceImei: str = Field(..., description="设备IMEI", min_length=14, max_length=16)
    deviceModelId: int = Field(..., description="设备型号ID", gt=0)
    deviceModelName: str = Field(..., description="设备型号名称", min_length=1, max_length=64)
    roomName: str = Field(..., description="安装点名称", min_length=1, max_length=128)
    deviceType: str = Field(..., description="设备类型名称", min_length=1, max_length=64)
    userId: Optional[int] = Field(None, description="已废弃：后端使用登录用户ID", gt=0)

    @field_validator("deviceImei")
    @classmethod
    def validate_imei(cls, v: str) -> str:
        """校验IMEI格式：14-16位数字"""
        v = v.strip()
        if not re.match(r"^\d{14,16}$", v):
            raise ValueError("IMEI必须是14-16位数字")
        return v

    @field_validator("deviceModelName", "roomName", "deviceType")
    @classmethod
    def validate_not_blank(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("字段不能为空")
        return v


class DeviceReportRequest(BaseModel):
    """设备报告查询请求"""
    userId: Optional[int] = Field(None, description="已废弃：后端使用登录用户ID", gt=0)
    eventStartDate: Optional[str] = Field(
        None,
        description="统计开始日期 YYYY-MM-DD，不传默认当天",
    )
    eventEndDate: Optional[str] = Field(
        None,
        description="统计结束日期 YYYY-MM-DD，不传默认当天",
    )

    @field_validator("eventStartDate", "eventEndDate")
    @classmethod
    def validate_date_text_optional(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v == "":
            return None
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError as exc:
            raise ValueError("日期格式必须为YYYY-MM-DD") from exc
        return v


class DeviceMetricTrendRequest(BaseModel):
    """设备指标趋势查询请求"""
    userId: Optional[int] = Field(None, description="已废弃：后端使用登录用户ID", gt=0)
    deviceImei: str = Field(..., description="设备IMEI", min_length=14, max_length=16)
    itemType: int = Field(..., description="指标类型：0心率 1血氧 2血压 3体温 4步数 5体动 6呼吸 7睡眠状态 8离床状态 9运动状态 10存在状态", ge=0, le=10)
    queryType: int = Field(..., description="查询维度：0日 1周 2月 3年", ge=0, le=3)
    startDate: str = Field(..., description="开始日期，yyyy-MM-dd")
    endDate: str = Field(..., description="结束日期，yyyy-MM-dd")

    @field_validator("deviceImei")
    @classmethod
    def validate_imei(cls, v: str) -> str:
        if not re.match(r"^\d{14,16}$", v):
            raise ValueError("IMEI必须是14-16位数字")
        return v

    @field_validator("startDate", "endDate")
    @classmethod
    def validate_date_text(cls, v: str) -> str:
        try:
            datetime.strptime(v, "%Y-%m-%d")
        except ValueError as exc:
            raise ValueError("日期格式必须为yyyy-MM-dd") from exc
        return v


class DeviceParamGetRequest(BaseModel):
    """设备参数查询请求"""
    deviceImei: str = Field(..., description="设备IMEI", min_length=14, max_length=16)

    @field_validator("deviceImei")
    @classmethod
    def validate_imei(cls, v: str) -> str:
        if not re.match(r"^\d{14,16}$", v):
            raise ValueError("IMEI必须是14-16位数字")
        return v


class DeviceParamItem(BaseModel):
    """设备参数设置项"""
    paramCode: str = Field(..., description="参数编码", min_length=1, max_length=32)
    paramValue: str = Field(..., description="参数值")


class DeviceParamSetRequest(BaseModel):
    """设备参数设置请求"""
    deviceImei: str = Field(..., description="设备IMEI", min_length=14, max_length=16)
    createBy: Optional[str] = Field(None, description="已废弃：后端使用登录用户作为操作人", max_length=32)
    paramCode: str = Field(..., description="参数编码", min_length=1, max_length=32)
    paramValue: str = Field(..., description="参数值")

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


# ========== IoT 平台客户端 ==========

class IoTPlatformClient:
    """物联网云平台 API 客户端"""

    def __init__(self, app_key: str, app_secret: str, base_url: str):
        self.app_key = app_key
        self.app_secret = app_secret
        self.base_url = base_url.rstrip('/')

    def _generate_signature(self, path: str, timestamp: str) -> str:
        """生成请求签名"""
        raw = path + timestamp + self.app_secret
        return hashlib.md5(raw.encode('utf-8')).hexdigest().upper()

    def post(self, path: str, data: dict) -> dict:
        """发送 POST 请求到平台"""
        url = self.base_url + path
        timestamp = str(int(time.time() * 1000))
        signature = self._generate_signature(path, timestamp)

        headers = {
            'Content-Type': 'application/json; charset=UTF-8',
            'timestamp': timestamp,
            'appKey': self.app_key,
            'signature': signature,
        }

        logger.info(f"平台请求: POST {url}")
        logger.info(
            "  Headers: {'Content-Type': 'application/json; charset=UTF-8', "
            f"'timestamp': '<redacted>', 'appKey': '{_mask_secret(self.app_key)}', "
            "'signature': '<redacted>'}"
        )
        logger.info(f"  Body: {json.dumps(data, ensure_ascii=False)}")

        response = requests.post(url, headers=headers, json=data, timeout=30)
        logger.info(f"  Response: {response.text}")
        response.raise_for_status()
        return response.json()


def _normalize_platform_device_state(state) -> int:
    """Map platform device state to local IoT device state."""
    try:
        state_value = int(state)
    except (TypeError, ValueError):
        return 4

    if state_value in (0, 1, 2, 4):
        return state_value
    if state_value == 3:
        return 2
    if state_value in (5, 6, 7):
        return 4
    return 4


def _normalize_device_model(value) -> str:
    return re.sub(r"[\s_\-]+", "", str(value or "").upper())


def _normalize_device_type_by_model(device_type, device_version) -> str | None:
    model = _normalize_device_model(device_version)
    if "GK8" in model:
        return "智能手表"
    if "GS17" in model:
        return "智能手环"
    if "RTC03" in model:
        return "跌倒雷达"
    if "SMC03" in model:
        return "睡眠雷达"
    return _blank_to_none(device_type)


def _parse_platform_datetime(value):
    if not value:
        return None
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(str(value), fmt)
        except ValueError:
            continue
    return None


def _blank_to_none(value):
    if value is None:
        return None
    if isinstance(value, str):
        value = value.strip()
        return value or None
    return value


def _sync_iot_user_devices_id_sequence(conn) -> None:
    """Keep BIGSERIAL sequence ahead of imported/manual iot_user_devices ids."""
    conn.execute("""
        DO $$
        DECLARE
            seq_name regclass;
        BEGIN
            SELECT pg_get_serial_sequence('iot_user_devices', 'id')::regclass INTO seq_name;
            IF seq_name IS NOT NULL THEN
                PERFORM setval(
                    seq_name,
                    COALESCE((SELECT MAX(id) FROM iot_user_devices), 0) + 1,
                    false
                );
            END IF;
        END $$;
    """)


def _save_user_device_binding(conn, user_id: int, device_id: int, device_imei: str) -> None:
    """Enable an existing user-device binding or insert a new one."""
    binding_row = conn.execute("""
        SELECT id, status
        FROM iot_user_devices
        WHERE user_id = %s
          AND device_id = %s
          AND device_imei = %s
        ORDER BY id
        LIMIT 1
    """, (user_id, device_id, device_imei)).fetchone()

    if binding_row:
        binding_id, status = binding_row
        if status != 1:
            conn.execute("""
                UPDATE iot_user_devices
                SET status = 1, updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
            """, (binding_id,))
        return

    legacy_row = conn.execute("""
        SELECT id, status
        FROM iot_user_devices
        WHERE user_id = %s
          AND device_id = %s
        ORDER BY id
        LIMIT 1
    """, (user_id, device_id)).fetchone()

    if legacy_row:
        binding_id, _status = legacy_row
        conn.execute("""
            UPDATE iot_user_devices
            SET device_imei = %s,
                status = 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (device_imei, binding_id))
        return

    _sync_iot_user_devices_id_sequence(conn)
    conn.execute("""
        INSERT INTO iot_user_devices (user_id, device_id, device_imei, status)
        VALUES (%s, %s, %s, 1)
    """, (user_id, device_id, device_imei))


# 创建平台客户端实例
platform_client = IoTPlatformClient(IOT_APP_KEY, IOT_APP_SECRET, IOT_PLATFORM_BASE_URL)


def _split_param_rows(item: DeviceParamItem) -> list[tuple[str, str, str]]:
    """
    Convert one API parameter item to database rows.
    JSON object values are expanded into field_name rows; plain values use an empty field_name.
    """
    param_code = item.paramCode.strip()
    param_value = item.paramValue.strip()

    try:
        decoded_value = json.loads(param_value)
    except json.JSONDecodeError:
        decoded_value = None

    rows = []
    if isinstance(decoded_value, dict):
        if not decoded_value:
            raise ValueError(f"参数 {param_code} 的 JSON 对象不能为空")
        for field_name, field_value in decoded_value.items():
            field_name = str(field_name).strip()
            value_text = field_value if isinstance(field_value, str) else json.dumps(field_value, ensure_ascii=False)
            value_text = str(value_text)
            if not field_name:
                raise ValueError(f"参数 {param_code} 存在空字段名")
            if len(field_name) > 32:
                raise ValueError(f"参数 {param_code} 字段名超过 32 个字符")
            if len(value_text) > 64:
                raise ValueError(f"参数 {param_code}.{field_name} 参数值超过 64 个字符")
            rows.append((param_code, field_name, value_text))
    else:
        if len(param_value) > 64:
            raise ValueError(f"参数 {param_code} 参数值超过 64 个字符")
        rows.append((param_code, "", param_value))

    return rows


def _format_param_rows(rows) -> list[dict]:
    """Group database parameter rows by paramCode for the response payload."""
    grouped: dict[str, dict[str, str]] = {}
    plain_values: dict[str, str] = {}

    for param_code, field_name, param_value in rows:
        if field_name:
            grouped.setdefault(param_code, {})[field_name] = param_value
        else:
            plain_values[param_code] = param_value

    param_codes = sorted(set(plain_values) | set(grouped))
    result = []
    for param_code in param_codes:
        fields = grouped.get(param_code)
        if fields:
            param_value = json.dumps(fields, ensure_ascii=False)
        else:
            param_value = plain_values.get(param_code, "")
        result.append({
            "paramCode": param_code,
            "paramValue": param_value,
        })

    return result


def _parse_metric_date(value: str) -> date:
    return datetime.strptime(value, "%Y-%m-%d").date()


def _validate_metric_date_range(req: DeviceMetricTrendRequest) -> tuple[date, date]:
    start_date = _parse_metric_date(req.startDate)
    end_date = _parse_metric_date(req.endDate)

    if start_date > end_date:
        raise ValueError("开始日期不能大于结束日期")

    if req.queryType == 0 and start_date != end_date:
        raise ValueError("日维度开始日期和结束日期必须相同")

    if req.queryType == 1 and (end_date - start_date).days + 1 > 7:
        raise ValueError("周维度最多选择7天")

    if req.queryType == 2 and (
        start_date.year != end_date.year or start_date.month != end_date.month
    ):
        raise ValueError("月维度开始日期和结束日期必须属于同一个自然月")

    if req.queryType == 3 and start_date.year != end_date.year:
        raise ValueError("年维度开始日期和结束日期必须属于同一个自然年")

    return start_date, end_date


def _bucket_unit(query_type: int) -> str:
    if query_type == 0:
        return "hour"
    if query_type in (1, 2):
        return "day"
    return "month"


def _x_axis_type(query_type: int) -> str:
    return _bucket_unit(query_type)


def _build_bucket_starts(
    start_date: date,
    end_date: date,
    query_type: int,
) -> list[datetime]:
    if query_type == 0:
        day_start = datetime.combine(start_date, datetime.min.time())
        return [day_start + timedelta(hours=hour) for hour in range(24)]

    if query_type in (1, 2):
        days = (end_date - start_date).days + 1
        return [
            datetime.combine(start_date + timedelta(days=offset), datetime.min.time())
            for offset in range(days)
        ]

    buckets = []
    current = date(start_date.year, start_date.month, 1)
    end_month = date(end_date.year, end_date.month, 1)
    while current <= end_month:
        buckets.append(datetime.combine(current, datetime.min.time()))
        if current.month == 12:
            current = date(current.year + 1, 1, 1)
        else:
            current = date(current.year, current.month + 1, 1)
    return buckets


def _bucket_end(bucket_start: datetime, query_type: int) -> datetime:
    if query_type == 0:
        next_bucket = bucket_start + timedelta(hours=1)
    elif query_type in (1, 2):
        next_bucket = bucket_start + timedelta(days=1)
    elif bucket_start.month == 12:
        next_bucket = datetime(bucket_start.year + 1, 1, 1)
    else:
        next_bucket = datetime(bucket_start.year, bucket_start.month + 1, 1)
    return next_bucket - timedelta(seconds=1)


def _bucket_label(bucket_start: datetime, query_type: int) -> str:
    if query_type == 0:
        return f"{bucket_start.hour:02d}:00"
    if query_type == 1:
        return f"{bucket_start.month}/{bucket_start.day}"
    if query_type == 2:
        return str(bucket_start.day)
    return f"{bucket_start.month}月"


def _format_datetime(value: datetime | None) -> str | None:
    return value.strftime("%Y-%m-%d %H:%M:%S") if value else None


def _raw_point_label(value: datetime) -> str:
    if value.second or value.microsecond:
        return value.strftime("%H:%M:%S")
    return value.strftime("%H:%M")


def _round_metric_value(value, fraction_digits: int):
    if value is None:
        return None
    numeric_value = round(float(value), fraction_digits)
    if fraction_digits == 0:
        return int(numeric_value)
    return numeric_value


def _format_metric_payload_value(value, fraction_digits: int):
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return _round_metric_value(value, fraction_digits)
    return str(value)


def _format_report_metric_value(attr_name: str, value) -> str:
    if value is None:
        return ""
    numeric_value = float(value)
    if attr_name == "温度":
        return f"{numeric_value:.1f}".rstrip("0").rstrip(".")
    return str(int(round(numeric_value)))


def _format_latest_metric_value(attr_name: str, value, value_text=None) -> str:
    text = str(value_text).strip() if value_text is not None else ""
    if text:
        return text
    try:
        return _format_report_metric_value(attr_name, value)
    except (TypeError, ValueError):
        return "" if value is None else str(value)


def _status_for_range(min_value, max_value, thresholds: dict) -> str | None:
    if min_value is None or max_value is None:
        return None
    if thresholds.get("safeHigh") is not None and max_value > thresholds["safeHigh"]:
        return "high"
    if thresholds.get("criticalLow") is not None and min_value < thresholds["criticalLow"]:
        return "critical_low"
    if thresholds.get("safeLow") is not None and min_value < thresholds["safeLow"]:
        return "low"
    return "normal"


def _metric_thresholds(metric_def: dict, series_def: dict) -> dict:
    thresholds = metric_def.get("thresholds", {})
    key = series_def["key"]
    if key in thresholds and isinstance(thresholds[key], dict):
        return thresholds[key]
    return thresholds


def _query_metric_rows(
    conn,
    *,
    imei: str,
    attr_name: str | list[str] | tuple[str, ...],
    start_dt: datetime,
    end_dt: datetime,
    bucket_unit: str,
    value_mode: str = "avg",
) -> dict[datetime, dict]:
    attr_names = [attr_name] if isinstance(attr_name, str) else list(attr_name)
    if value_mode == "total" and attr_names == ["计步"]:
        return _query_step_metric_rows(
            conn,
            imei=imei,
            attr_name=attr_names[0],
            start_dt=start_dt,
            end_dt=end_dt,
            bucket_unit=bucket_unit,
        )

    attr_placeholders = ",".join(["%s"] * len(attr_names))
    result = conn.execute(f"""
        WITH filtered AS (
            SELECT
                date_trunc(%s::text, sign_time) AS bucket,
                sign_time,
                id,
                attr_value AS numeric_value,
                prop_value AS prop_value
            FROM iot_health_event_items
            WHERE imei = %s
              AND attr_name IN ({attr_placeholders})
              AND sign_time >= %s
              AND sign_time < %s
              AND (attr_value IS NOT NULL OR prop_value IS NOT NULL)
        ),
        numeric_agg AS (
            SELECT
                bucket,
                AVG(numeric_value) AS avg_value,
                SUM(numeric_value) AS total_value,
                MIN(numeric_value) AS min_value,
                MAX(numeric_value) AS max_value,
                COUNT(*)::int AS item_count
            FROM filtered
            WHERE numeric_value IS NOT NULL
            GROUP BY bucket
        ),
        numeric_latest AS (
            SELECT DISTINCT ON (bucket)
                bucket,
                numeric_value AS last_value,
                sign_time AS report_time
            FROM filtered
            WHERE numeric_value IS NOT NULL
            ORDER BY bucket, sign_time DESC, id DESC
        ),
        prop_stats AS (
            SELECT
                bucket,
                COUNT(*)::int AS item_count
            FROM filtered
            WHERE prop_value IS NOT NULL
            GROUP BY bucket
        ),
        prop_latest AS (
            SELECT DISTINCT ON (bucket)
                bucket,
                prop_value AS prop_value,
                sign_time AS report_time
            FROM filtered
            WHERE prop_value IS NOT NULL
            ORDER BY bucket, sign_time DESC, id DESC
        ),
        buckets AS (
            SELECT bucket FROM filtered GROUP BY bucket
        )
        SELECT
            b.bucket,
            n.avg_value,
            n.total_value,
            n.min_value,
            n.max_value,
            nl.last_value,
            nl.report_time,
            COALESCE(n.item_count, 0) AS numeric_count,
            pl.prop_value,
            pl.report_time AS prop_report_time,
            COALESCE(ps.item_count, 0) AS prop_count
        FROM buckets b
        LEFT JOIN numeric_agg n ON n.bucket = b.bucket
        LEFT JOIN numeric_latest nl ON nl.bucket = b.bucket
        LEFT JOIN prop_stats ps ON ps.bucket = b.bucket
        LEFT JOIN prop_latest pl ON pl.bucket = b.bucket
        ORDER BY b.bucket
    """, (
        bucket_unit,
        imei,
        *attr_names,
        start_dt,
        end_dt,
    ))

    rows = {}
    for (
        bucket,
        avg_value,
        total_value,
        min_value,
        max_value,
        last_value,
        report_time,
        numeric_count,
        prop_value,
        prop_report_time,
        prop_count,
    ) in result.fetchall():
        normalized_bucket = (
            bucket.replace(minute=0, second=0, microsecond=0)
            if bucket_unit == "hour"
            else bucket
        )
        has_numeric_value = numeric_count > 0
        rows[normalized_bucket] = {
            "avgValue": avg_value if has_numeric_value else prop_value,
            "totalValue": total_value if has_numeric_value else None,
            "minValue": min_value if has_numeric_value else None,
            "maxValue": max_value if has_numeric_value else None,
            "lastValue": last_value if has_numeric_value else prop_value,
            "reportTime": report_time if has_numeric_value else prop_report_time,
            "count": numeric_count if has_numeric_value else prop_count,
            "valueType": "number" if has_numeric_value else "text",
        }
    return rows


def _query_metric_raw_points(
    conn,
    *,
    imei: str,
    attr_name: str | list[str] | tuple[str, ...],
    start_dt: datetime,
    end_dt: datetime,
) -> list[dict]:
    attr_names = [attr_name] if isinstance(attr_name, str) else list(attr_name)
    attr_placeholders = ",".join(["%s"] * len(attr_names))
    result = conn.execute(f"""
        SELECT
            sign_time,
            id,
            attr_value AS numeric_value,
            prop_value AS prop_value
        FROM iot_health_event_items
        WHERE imei = %s
          AND attr_name IN ({attr_placeholders})
          AND sign_time >= %s
          AND sign_time < %s
          AND (attr_value IS NOT NULL OR prop_value IS NOT NULL)
        ORDER BY sign_time, id
    """, (
        imei,
        *attr_names,
        start_dt,
        end_dt,
    ))

    rows = []
    for sign_time, row_id, numeric_value, prop_value in result.fetchall():
        has_numeric_value = numeric_value is not None
        rows.append({
            "id": row_id,
            "reportTime": sign_time,
            "avgValue": numeric_value if has_numeric_value else prop_value,
            "totalValue": None,
            "minValue": numeric_value if has_numeric_value else None,
            "maxValue": numeric_value if has_numeric_value else None,
            "lastValue": numeric_value if has_numeric_value else prop_value,
            "count": 1,
            "valueType": "number" if has_numeric_value else "text",
        })
    return rows


def _query_step_metric_rows(
    conn,
    *,
    imei: str,
    attr_name: str,
    start_dt: datetime,
    end_dt: datetime,
    bucket_unit: str,
) -> dict[datetime, dict]:
    if bucket_unit == "month":
        result = conn.execute("""
            WITH filtered AS (
                SELECT
                    date_trunc('month', sign_time) AS bucket,
                    date_trunc('day', sign_time) AS step_day,
                    sign_time,
                    id,
                    attr_value AS value
                FROM iot_health_event_items
                WHERE imei = %s
                  AND attr_name = %s
                  AND sign_time >= %s
                  AND sign_time < %s
                  AND attr_value IS NOT NULL
            ),
            daily_latest AS (
                SELECT DISTINCT ON (step_day)
                    bucket,
                    step_day,
                    value AS daily_total,
                    sign_time AS report_time,
                    id
                FROM filtered
                ORDER BY step_day, sign_time DESC, id DESC
            ),
            agg AS (
                SELECT
                    bucket,
                    SUM(daily_total) AS total_value,
                    COUNT(*)::int AS item_count
                FROM daily_latest
                GROUP BY bucket
            ),
            latest AS (
                SELECT DISTINCT ON (bucket)
                    bucket,
                    daily_total AS last_value,
                    report_time
                FROM daily_latest
                ORDER BY bucket, report_time DESC, id DESC
            )
            SELECT
                a.bucket,
                NULL AS avg_value,
                a.total_value,
                NULL AS min_value,
                NULL AS max_value,
                l.last_value,
                l.report_time,
                a.item_count
            FROM agg a
            LEFT JOIN latest l ON l.bucket = a.bucket
            ORDER BY a.bucket
        """, (
            imei,
            attr_name,
            start_dt,
            end_dt,
        ))
    else:
        result = conn.execute("""
            WITH filtered AS (
                SELECT
                    date_trunc(%s::text, sign_time) AS bucket,
                    sign_time,
                    id,
                    attr_value AS value
                FROM iot_health_event_items
                WHERE imei = %s
                  AND attr_name = %s
                  AND sign_time >= %s
                  AND sign_time < %s
                  AND attr_value IS NOT NULL
            ),
            stats AS (
                SELECT
                    bucket,
                    COUNT(*)::int AS item_count
                FROM filtered
                GROUP BY bucket
            ),
            latest AS (
                SELECT DISTINCT ON (bucket)
                    bucket,
                    value AS total_value,
                    value AS last_value,
                    sign_time AS report_time
                FROM filtered
                ORDER BY bucket, sign_time DESC, id DESC
            )
            SELECT
                l.bucket,
                NULL AS avg_value,
                l.total_value,
                NULL AS min_value,
                NULL AS max_value,
                l.last_value,
                l.report_time,
                s.item_count
            FROM latest l
            LEFT JOIN stats s ON s.bucket = l.bucket
            ORDER BY l.bucket
        """, (
            bucket_unit,
            imei,
            attr_name,
            start_dt,
            end_dt,
        ))

    rows = {}
    for (
        bucket,
        avg_value,
        total_value,
        min_value,
        max_value,
        last_value,
        report_time,
        item_count,
    ) in result.fetchall():
        normalized_bucket = (
            bucket.replace(minute=0, second=0, microsecond=0)
            if bucket_unit == "hour"
            else bucket
        )
        rows[normalized_bucket] = {
            "avgValue": avg_value,
            "totalValue": total_value,
            "minValue": min_value,
            "maxValue": max_value,
            "lastValue": last_value,
            "reportTime": report_time,
            "count": item_count,
        }
    return rows


def _raw_point_payload(
    *,
    point_time: datetime,
    row: dict,
    fraction_digits: int,
    value_mode: str,
    thresholds: dict,
) -> dict:
    value_type = row.get("valueType") or "number"
    if value_type == "text":
        avg_value = _format_metric_payload_value(row["avgValue"], fraction_digits)
        total_value = None
        min_value = None
        max_value = None
        last_value = _format_metric_payload_value(row["lastValue"], fraction_digits)
        status = "normal" if avg_value is not None else None
    else:
        avg_value = _round_metric_value(row["avgValue"], fraction_digits)
        total_value = _round_metric_value(row["totalValue"], fraction_digits)
        min_value = _round_metric_value(row["minValue"], fraction_digits)
        max_value = _round_metric_value(row["maxValue"], fraction_digits)
        last_value = _round_metric_value(row["lastValue"], fraction_digits)

        if value_mode == "total":
            total_value = total_value if total_value is not None else last_value
            avg_value = None
            min_value = None
            max_value = None
            status = "normal" if total_value is not None else None
        else:
            total_value = None
            status = _status_for_range(min_value, max_value, thresholds)

    return {
        "_bucket": point_time,
        "label": _raw_point_label(point_time),
        "bucketStart": _format_datetime(point_time),
        "bucketEnd": _format_datetime(point_time),
        "avgValue": avg_value,
        "totalValue": total_value,
        "minValue": min_value,
        "maxValue": max_value,
        "lastValue": last_value,
        "reportTime": _format_datetime(row["reportTime"]),
        "count": row["count"],
        "valueType": value_type,
        "status": status,
    }


def _empty_point(bucket_start: datetime, query_type: int) -> dict:
    return {
        "_bucket": bucket_start,
        "label": _bucket_label(bucket_start, query_type),
        "bucketStart": _format_datetime(bucket_start),
        "bucketEnd": _format_datetime(_bucket_end(bucket_start, query_type)),
        "avgValue": None,
        "totalValue": None,
        "minValue": None,
        "maxValue": None,
        "lastValue": None,
        "reportTime": None,
        "count": 0,
        "valueType": None,
        "status": None,
    }


def _build_raw_series_payload(
    *,
    metric_def: dict,
    series_def: dict,
    rows: list[dict],
    query_type: int,
) -> dict:
    fraction_digits = series_def.get("fractionDigits", 0)
    value_mode = series_def.get("valueMode", "avg")
    thresholds = _metric_thresholds(metric_def, series_def)
    points = []

    for row in rows:
        point_time = row["reportTime"]
        points.append(
            _raw_point_payload(
                point_time=point_time,
                row=row,
                fraction_digits=fraction_digits,
                value_mode=value_mode,
                thresholds=thresholds,
            )
        )

    summary = _build_series_summary(
        points=points,
        fraction_digits=fraction_digits,
        value_mode=value_mode,
        thresholds=thresholds,
        query_type=query_type,
    )

    response_points = []
    for point in points:
        item = dict(point)
        item.pop("_bucket", None)
        response_points.append(item)

    return {
        "key": series_def["key"],
        "name": series_def["name"],
        "unit": series_def["unit"],
        "summary": summary,
        "points": response_points,
        "_points": points,
    }


def _build_series_payload(
    *,
    metric_def: dict,
    series_def: dict,
    rows_by_bucket: dict[datetime, dict],
    bucket_starts: list[datetime],
    query_type: int,
) -> dict:
    fraction_digits = series_def.get("fractionDigits", 0)
    value_mode = series_def.get("valueMode", "avg")
    thresholds = _metric_thresholds(metric_def, series_def)
    points = []

    for bucket_start in bucket_starts:
        row = rows_by_bucket.get(bucket_start)
        if row is None:
            points.append(_empty_point(bucket_start, query_type))
            continue

        value_type = row.get("valueType") or "number"
        if value_type == "text":
            avg_value = _format_metric_payload_value(
                row["avgValue"], fraction_digits
            )
            total_value = None
            min_value = None
            max_value = None
            last_value = _format_metric_payload_value(
                row["lastValue"], fraction_digits
            )
            status = "normal" if avg_value is not None else None
        else:
            avg_value = _round_metric_value(row["avgValue"], fraction_digits)
            total_value = _round_metric_value(row["totalValue"], fraction_digits)
            min_value = _round_metric_value(row["minValue"], fraction_digits)
            max_value = _round_metric_value(row["maxValue"], fraction_digits)
            last_value = _round_metric_value(row["lastValue"], fraction_digits)

            if value_mode == "total":
                avg_value = None
                min_value = None
                max_value = None
                status = "normal" if total_value is not None else None
            else:
                total_value = None
                status = _status_for_range(min_value, max_value, thresholds)

        points.append({
            "_bucket": bucket_start,
            "label": _bucket_label(bucket_start, query_type),
            "bucketStart": _format_datetime(bucket_start),
            "bucketEnd": _format_datetime(_bucket_end(bucket_start, query_type)),
            "avgValue": avg_value,
            "totalValue": total_value,
            "minValue": min_value,
            "maxValue": max_value,
            "lastValue": last_value,
            "reportTime": _format_datetime(row["reportTime"]),
            "count": row["count"],
            "valueType": value_type,
            "status": status,
        })

    summary = _build_series_summary(
        points=points,
        fraction_digits=fraction_digits,
        value_mode=value_mode,
        thresholds=thresholds,
        query_type=query_type,
    )

    response_points = []
    for point in points:
        item = dict(point)
        item.pop("_bucket", None)
        response_points.append(item)

    return {
        "key": series_def["key"],
        "name": series_def["name"],
        "unit": series_def["unit"],
        "summary": summary,
        "points": response_points,
        "_points": points,
    }


def _build_series_summary(
    *,
    points: list[dict],
    fraction_digits: int,
    value_mode: str,
    thresholds: dict,
    query_type: int,
) -> dict:
    data_points = [point for point in points if point["count"] > 0]
    if not data_points:
        return {
            "avgValue": None,
            "totalValue": None,
            "minValue": None,
            "maxValue": None,
            "lastValue": None,
            "reportTime": None,
            "count": 0,
            "valueType": None,
            "status": None,
        }

    latest_point = max(
        data_points,
        key=lambda point: point["reportTime"] or point["bucketStart"],
    )
    count = sum(point["count"] for point in data_points)

    if value_mode == "total":
        if query_type == 0:
            total_value = (
                latest_point["totalValue"]
                if latest_point["totalValue"] is not None
                else latest_point["lastValue"]
            )
        else:
            total_value = sum(point["totalValue"] or 0 for point in data_points)
        return {
            "avgValue": None,
            "totalValue": _round_metric_value(total_value, fraction_digits),
            "minValue": None,
            "maxValue": None,
            "lastValue": latest_point["lastValue"],
            "reportTime": latest_point["reportTime"],
            "count": count,
            "valueType": "number",
            "status": "normal",
        }

    numeric_data_points = [
        point for point in data_points if point.get("valueType") == "number"
    ]
    if not numeric_data_points:
        return {
            "avgValue": latest_point["avgValue"],
            "totalValue": None,
            "minValue": None,
            "maxValue": None,
            "lastValue": latest_point["lastValue"],
            "reportTime": latest_point["reportTime"],
            "count": count,
            "valueType": "text",
            "status": latest_point["status"],
        }

    count = sum(point["count"] for point in numeric_data_points)
    latest_numeric_point = max(
        numeric_data_points,
        key=lambda point: point["reportTime"] or point["bucketStart"],
    )
    weighted_total = sum(
        (point["avgValue"] or 0) * point["count"]
        for point in numeric_data_points
    )
    avg_value = _round_metric_value(weighted_total / count, fraction_digits)
    min_value = min(
        point["minValue"]
        for point in numeric_data_points
        if point["minValue"] is not None
    )
    max_value = max(
        point["maxValue"]
        for point in numeric_data_points
        if point["maxValue"] is not None
    )
    return {
        "avgValue": avg_value,
        "totalValue": None,
        "minValue": min_value,
        "maxValue": max_value,
        "lastValue": latest_numeric_point["lastValue"],
        "reportTime": latest_numeric_point["reportTime"],
        "count": count,
        "valueType": "number",
        "status": _status_for_range(min_value, max_value, thresholds),
    }


def _combine_status(statuses: list[str | None]) -> str | None:
    filtered = [status for status in statuses if status]
    if not filtered:
        return None
    if "high" in filtered:
        return "high"
    if "critical_low" in filtered:
        return "critical_low"
    if "low" in filtered:
        return "low"
    return "normal"


def _build_latest_payload(series_payloads: list[dict]) -> dict:
    points_with_data = [
        point
        for series in series_payloads
        for point in series["_points"]
        if point["count"] > 0
    ]
    if not points_with_data:
        return {"label": None, "reportTime": None, "values": {}, "status": None}

    latest_bucket = max(point["_bucket"] for point in points_with_data)
    values = {}
    statuses = []
    report_times = []
    label = None

    for series in series_payloads:
        point = next(
            (item for item in series["_points"] if item["_bucket"] == latest_bucket),
            None,
        )
        if point is None or point["count"] == 0:
            continue
        label = point["label"]
        values[series["key"]] = (
            point["totalValue"]
            if point["totalValue"] is not None
            else point["lastValue"]
        )
        statuses.append(point["status"])
        if point["reportTime"]:
            report_times.append(point["reportTime"])

    return {
        "label": label,
        "reportTime": max(report_times) if report_times else None,
        "values": values,
        "status": _combine_status(statuses),
    }


def _strip_internal_fields(series_payloads: list[dict]) -> list[dict]:
    result = []
    for series in series_payloads:
        item = dict(series)
        item.pop("_points", None)
        result.append(item)
    return result


# ========== 接口实现 ==========

@router.post("/devices/add", summary="新增设备")
async def add_device(
    req: DeviceAddRequest,
    current_user: User = Depends(get_current_user),
):
    """
    新增设备接口

    1. 调用平台接口查询单个设备信息
    2. 保存平台设备信息和接警人到本地数据库
    3. 保存用户设备关系
    """
    user_id = current_iot_user_id(current_user)
    logger.info(f"新增设备请求: imei={req.deviceImei}, userId={user_id}")
    _ensure_iot_platform_configured()

    # 1. 调用平台接口查询设备信息
    try:
        platform_data = {
            "deviceImei": req.deviceImei,
            "fullFlag": 0,
        }
        platform_result = await asyncio.to_thread(
            platform_client.post, "/api/v1/dev/get", platform_data
        )

        if not platform_result.get("success"):
            logger.error(f"平台查询设备失败: {platform_result}")
            return ApiResponse(
                code=platform_result.get("code", "ERROR"),
                success=False,
                message={"msg": str(platform_result.get("message") or "设备添加失败")}
            )

        platform_device = platform_result.get("message")
        if not isinstance(platform_device, dict):
            logger.error(f"平台返回设备数据异常: {platform_result}")
            return ApiResponse(
                code="ERROR",
                success=False,
                message={"msg": "平台返回设备数据异常"}
            )

        returned_imei = str(platform_device.get("deviceImei") or req.deviceImei).strip()
        if returned_imei != req.deviceImei:
            logger.error(
                f"平台返回设备IMEI不匹配: request={req.deviceImei}, response={returned_imei}"
            )
            return ApiResponse(
                code="ERROR",
                success=False,
                message={"msg": "平台返回设备与请求设备不一致"}
            )

        try:
            device_id = int(platform_device.get("deviceId"))
        except (TypeError, ValueError):
            device_id = None

        if not device_id:
            logger.error(f"平台返回缺少 deviceId: {platform_result}")
            return ApiResponse(
                code="ERROR",
                success=False,
                message={"msg": "平台返回数据异常"}
            )

        logger.info(f"平台查询设备成功: deviceId={device_id}, imei={req.deviceImei}")

    except Exception as e:
        logger.error(f"调用平台接口异常: {e}")
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": f"调用平台接口失败: {str(e)}"}
        )

    # 2. 保存设备信息到本地数据库
    def _save_device():
        with get_connection() as conn:
            device_type = _blank_to_none(req.deviceType) or _blank_to_none(platform_device.get("deviceTypeName"))
            device_version = _blank_to_none(req.deviceModelName) or _blank_to_none(platform_device.get("deviceModelName"))
            device_type = _normalize_device_type_by_model(device_type, device_version)
            room_name = _blank_to_none(req.roomName) or _blank_to_none(platform_device.get("roomName"))
            site = _blank_to_none(platform_device.get("installAddress")) or room_name

            # 保存设备信息
            conn.execute("""
                INSERT INTO iot_devices (
                    imei, iccid, device_type, device_version, device_model_id, device_state,
                    longitude, latitude, site, room_name, company_name, enabled_time
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (imei) DO UPDATE SET
                    iccid = COALESCE(EXCLUDED.iccid, iot_devices.iccid),
                    device_type = COALESCE(EXCLUDED.device_type, iot_devices.device_type),
                    device_version = COALESCE(EXCLUDED.device_version, iot_devices.device_version),
                    device_model_id = COALESCE(EXCLUDED.device_model_id, iot_devices.device_model_id),
                    device_state = EXCLUDED.device_state,
                    longitude = COALESCE(EXCLUDED.longitude, iot_devices.longitude),
                    latitude = COALESCE(EXCLUDED.latitude, iot_devices.latitude),
                    site = COALESCE(EXCLUDED.site, iot_devices.site),
                    room_name = COALESCE(EXCLUDED.room_name, iot_devices.room_name),
                    company_name = COALESCE(EXCLUDED.company_name, iot_devices.company_name),
                    enabled_time = COALESCE(EXCLUDED.enabled_time, iot_devices.enabled_time),
                    updated_at = CURRENT_TIMESTAMP
            """, (
                req.deviceImei,
                _blank_to_none(platform_device.get("iccid")),
                device_type,
                device_version,
                req.deviceModelId,
                _normalize_platform_device_state(platform_device.get("state")),
                _blank_to_none(platform_device.get("longitude")),
                _blank_to_none(platform_device.get("latitude")),
                site,
                room_name,
                _blank_to_none(platform_device.get("companyName")),
                _parse_platform_datetime(platform_device.get("createTime")),
            ))

            contact_phone = str(platform_device.get("phonenumber") or "").strip()
            if contact_phone:
                conn.execute("""
                    INSERT INTO iot_device_contacts (imei, name, phone, contact_type)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (imei, phone) DO UPDATE SET
                        name = COALESCE(EXCLUDED.name, iot_device_contacts.name),
                        contact_type = COALESCE(EXCLUDED.contact_type, iot_device_contacts.contact_type)
                """, (
                    req.deviceImei,
                    _blank_to_none(platform_device.get("contact")),
                    contact_phone,
                    1,
                ))

            # 保存用户设备关系
            _save_user_device_binding(conn, user_id, device_id, req.deviceImei)

    try:
        await asyncio.to_thread(_save_device)
    except Exception as e:
        logger.error(f"保存设备信息失败: {e}")
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": f"保存设备信息失败: {str(e)}"}
        )

    # 3. 返回成功
    return ApiResponse(
        code="OK",
        success=True,
        message={
            "data": f"设备：{req.deviceImei}；添加成功！",
            "deviceId": device_id,
        }
    )


@router.get("/device/type_dict", summary="获取设备类型字典")
async def get_device_type_dict(_current_user: User = Depends(get_current_user)):
    """
    获取设备类型字典接口

    返回所有启用的设备类型
    """
    logger.info("获取设备类型字典")

    def _query_types():
        with get_connection() as conn:
            result = conn.execute("""
                SELECT id, code, name FROM iot_device_types
                WHERE status = 1
                ORDER BY id
            """)
            rows = result.fetchall()
            return [{"id": r[0], "code": r[1], "name": r[2]} for r in rows]

    try:
        types = await asyncio.to_thread(_query_types)
        return ApiResponse(
            code="OK",
            success=True,
            message={"data": types}
        )
    except Exception as e:
        logger.error(f"查询设备类型失败: {e}")
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": f"查询失败: {str(e)}"}
        )


@router.post("/device/param/get", summary="查询设备参数")
async def get_device_params(
    req: DeviceParamGetRequest,
    current_user: User = Depends(get_current_user),
):
    """查询设备参数配置"""
    logger.info(f"查询设备参数: imei={req.deviceImei}")

    def _query_params():
        with get_connection() as conn:
            ensure_device_access(conn, current_iot_user_id(current_user), req.deviceImei)
            result = conn.execute("""
                SELECT param_code, field_name, param_value
                FROM iot_device_params
                WHERE imei = %s
                ORDER BY param_code, id
            """, (req.deviceImei,))
            return _format_param_rows(result.fetchall())

    try:
        params = await asyncio.to_thread(_query_params)
        return {
            "success": True,
            "code": "OK",
            "msg": "OK",
            "data": params,
        }
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except Exception as e:
        logger.error(f"查询设备参数失败: {e}")
        return {
            "success": False,
            "code": "ERROR",
            "msg": f"查询失败: {str(e)}",
            "data": [],
        }


@router.post("/device/param/set", summary="设置设备参数")
async def set_device_params(
    req: DeviceParamSetRequest,
    current_user: User = Depends(get_current_user),
):
    """设置设备参数：先下发平台任务，全部成功后写入本地参数表"""
    user_id = current_iot_user_id(current_user)
    operator_name = current_operator_name(current_user)
    logger.info(
        f"设置设备参数: imei={req.deviceImei}, userId={user_id}, "
        f"paramCode={req.paramCode}"
    )
    _ensure_iot_platform_configured()

    try:
        item = DeviceParamItem(paramCode=req.paramCode, paramValue=req.paramValue)
        db_rows = _split_param_rows(item)
    except ValueError as e:
        return {
            "code": "ERROR",
            "success": False,
            "message": str(e),
        }

    def _device_exists():
        with get_connection() as conn:
            ensure_device_access(conn, user_id, req.deviceImei)
            return True

    try:
        exists = await asyncio.to_thread(_device_exists)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except Exception as e:
        logger.error(f"校验设备失败: {e}")
        return {
            "code": "ERROR",
            "success": False,
            "message": f"校验设备失败: {str(e)}",
        }

    if not exists:
        return {
            "code": "ERROR",
            "success": False,
            "message": "设备不存在",
        }

    platform_payload = {
        "deviceImei": req.deviceImei,
        "createBy": operator_name,
        "paramCode": req.paramCode.strip(),
        "paramValue": req.paramValue.strip(),
    }

    try:
        platform_result = await asyncio.to_thread(
            platform_client.post,
            "/api/v1/cmd/createTask",
            platform_payload,
        )
    except Exception as e:
        logger.error(f"平台参数设置异常: payload={platform_payload}, error={e}")
        return {
            "code": "ERROR",
            "success": False,
            "message": f"平台参数设置失败: {str(e)}",
        }

    if not platform_result.get("success"):
        logger.error(f"平台参数设置失败: payload={platform_payload}, result={platform_result}")
        return {
            "code": platform_result.get("code", "ERROR"),
            "success": False,
            "message": platform_result.get("msg") or platform_result.get("message") or "平台参数设置失败",
        }

    def _save_params():
        with get_connection() as conn:
            for param_code, field_name, param_value in db_rows:
                conn.execute("""
                    INSERT INTO iot_device_params
                        (imei, param_code, field_name, param_value, create_by)
                    VALUES
                        (%s, %s, %s, %s, %s)
                    ON CONFLICT (imei, param_code, field_name) DO UPDATE SET
                        param_value = EXCLUDED.param_value,
                        create_by = EXCLUDED.create_by,
                        updated_at = CURRENT_TIMESTAMP
                """, (req.deviceImei, param_code, field_name, param_value, operator_name))

    try:
        await asyncio.to_thread(_save_params)
    except Exception as e:
        logger.error(f"保存设备参数失败: {e}")
        return {
            "code": "ERROR",
            "success": False,
            "message": f"保存设备参数失败: {str(e)}",
        }

    return {
        "code": "OK",
        "success": True,
        "message": "设置成功",
    }


@router.post("/device/metric/trend", summary="获取设备指标趋势")
async def get_device_metric_trend(
    req: DeviceMetricTrendRequest,
    current_user: User = Depends(get_current_user),
):
    """获取单设备单指标趋势详情数据"""
    user_id = current_iot_user_id(current_user)
    logger.info(
        f"获取设备指标趋势: userId={user_id}, imei={req.deviceImei}, "
        f"itemType={req.itemType}, queryType={req.queryType}, "
        f"startDate={req.startDate}, endDate={req.endDate}"
    )

    try:
        start_date, end_date = _validate_metric_date_range(req)
    except ValueError as e:
        return {
            "code": "ERROR",
            "success": False,
            "message": str(e),
        }

    metric_def = METRIC_DEFINITIONS[req.itemType]
    bucket_starts = _build_bucket_starts(start_date, end_date, req.queryType)
    bucket_unit = _bucket_unit(req.queryType)
    start_dt = datetime.combine(start_date, datetime.min.time())
    end_dt = datetime.combine(end_date + timedelta(days=1), datetime.min.time())

    def _query_trend():
        with get_connection() as conn:
            device_row = conn.execute("""
                SELECT d.device_type, d.device_version
                FROM iot_user_devices ud
                LEFT JOIN iot_devices d ON d.imei = ud.device_imei
                WHERE ud.user_id = %s
                  AND ud.device_imei = %s
                  AND ud.status = 1
                LIMIT 1
            """, (user_id, req.deviceImei)).fetchone()

            if device_row is None:
                raise PermissionError("设备不存在或无访问权限")

            device_type = _normalize_device_type_by_model(device_row[0], device_row[1])
            use_raw_day_points = (
                req.queryType == 0
                and (
                    (device_type == "睡眠雷达" and req.itemType in (0, 5, 6))
                    or (
                        device_type in ("智能手表", "智能手环")
                        and req.itemType in (0, 2, 3, 4)
                    )
                )
            )
            series_payloads = []
            for series_def in metric_def["series"]:
                if use_raw_day_points:
                    rows = _query_metric_raw_points(
                        conn,
                        imei=req.deviceImei,
                        attr_name=series_def.get("attrNames") or series_def["attrName"],
                        start_dt=start_dt,
                        end_dt=end_dt,
                    )
                    series_payloads.append(
                        _build_raw_series_payload(
                            metric_def=metric_def,
                            series_def=series_def,
                            rows=rows,
                            query_type=req.queryType,
                        )
                    )
                else:
                    rows_by_bucket = _query_metric_rows(
                        conn,
                        imei=req.deviceImei,
                        attr_name=series_def.get("attrNames") or series_def["attrName"],
                        start_dt=start_dt,
                        end_dt=end_dt,
                        bucket_unit=bucket_unit,
                        value_mode=series_def.get("valueMode", "avg"),
                    )
                    series_payloads.append(
                        _build_series_payload(
                            metric_def=metric_def,
                            series_def=series_def,
                            rows_by_bucket=rows_by_bucket,
                            bucket_starts=bucket_starts,
                            query_type=req.queryType,
                        )
                    )

            latest = _build_latest_payload(series_payloads)
            return {
                "deviceImei": req.deviceImei,
                "itemType": req.itemType,
                "itemName": metric_def["itemName"],
                "queryType": req.queryType,
                "unit": metric_def["unit"],
                "xAxisType": "time" if use_raw_day_points else _x_axis_type(req.queryType),
                "startDate": req.startDate,
                "endDate": req.endDate,
                "series": _strip_internal_fields(series_payloads),
                "latest": latest,
                "thresholds": metric_def["thresholds"],
            }

    try:
        trend_data = await asyncio.to_thread(_query_trend)
        return {
            "code": "OK",
            "success": True,
            "message": {"data": trend_data},
        }
    except PermissionError as e:
        return {
            "code": "ERROR",
            "success": False,
            "message": str(e),
        }
    except Exception as e:
        logger.error(f"查询设备指标趋势失败: {e}")
        return {
            "code": "ERROR",
            "success": False,
            "message": f"查询失败: {str(e)}",
        }


@router.post("/device/report", summary="获取设备检测报告")
async def get_device_report(
    req: DeviceReportRequest,
    current_user: User = Depends(get_current_user),
):
    """
    获取设备检测报告接口

    根据用户ID查询绑定的设备及其最新上报数据
    使用 JOIN 批量查询优化性能
    """
    today = datetime.now().strftime("%Y-%m-%d")
    event_start_date = req.eventStartDate or req.eventEndDate or today
    event_end_date = req.eventEndDate or req.eventStartDate or today

    if (
        datetime.strptime(event_start_date, "%Y-%m-%d").date()
        > datetime.strptime(event_end_date, "%Y-%m-%d").date()
    ):
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": "统计开始日期不能大于结束日期"}
        )

    user_id = current_iot_user_id(current_user)
    logger.info(f"获取设备报告: userId={user_id}, date={event_start_date}~{event_end_date}")

    def _query_report():
        with get_connection() as conn:
            # 1. 批量查询用户绑定的设备及其最新事件（使用 JOIN 优化）
            result = conn.execute("""
                SELECT
                    ud.device_id,
                    ud.device_imei,
                    d.device_type,
                    d.device_version,
                    COALESCE(d.room_name, d.site) as room_name,
                    e.device_state,
                    e.sign_time
                FROM iot_user_devices ud
                LEFT JOIN iot_devices d ON d.imei = ud.device_imei
                LEFT JOIN LATERAL (
                    SELECT device_state, sign_time
                    FROM (
                        (SELECT device_state, sign_time, id, 1 AS source_order
                         FROM iot_alarm_events
                         WHERE imei = ud.device_imei
                         ORDER BY sign_time DESC NULLS LAST, id DESC
                         LIMIT 1)
                        UNION ALL
                        (SELECT device_state, sign_time, id, 2 AS source_order
                         FROM iot_health_events
                         WHERE imei = ud.device_imei
                         ORDER BY sign_time DESC NULLS LAST, id DESC
                         LIMIT 1)
                        UNION ALL
                        (SELECT device_state, sign_time, id, 3 AS source_order
                         FROM iot_heartbeat_events
                         WHERE imei = ud.device_imei
                         ORDER BY sign_time DESC NULLS LAST, id DESC
                         LIMIT 1)
                    ) latest_event
                    ORDER BY sign_time DESC NULLS LAST, source_order, id DESC
                    LIMIT 1
                ) e ON true
                WHERE ud.user_id = %s AND ud.status = 1
            """, (user_id,))
            device_rows = result.fetchall()

            if not device_rows:
                return []

            def _row_device_type(row) -> str | None:
                return _normalize_device_type_by_model(row[2], row[3])

            # 2. 按设备类型分组，分别查询
            # 智能手环/智能手表：查询属性
            wearables_imeis = [row[1] for row in device_rows
                               if _row_device_type(row) in ("智能手环", "智能手表") and row[1]]
            # 跌倒雷达/睡眠雷达：查询报警数量和事件上报数量
            radars_imeis = [row[1] for row in device_rows
                           if _row_device_type(row) in ("跌倒雷达", "睡眠雷达") and row[1]]
            sleep_radars_imeis = [row[1] for row in device_rows
                                  if _row_device_type(row) == "睡眠雷达" and row[1]]

            items_map = {}      # imei -> items list（手环/手表）
            alarm_map = {}      # imei -> alarm count（雷达）
            event_count_map = {}  # imei -> heartbeat event count（雷达）
            radar_items_map = {}  # imei -> latest health metric items（睡眠雷达）

            if wearables_imeis:
                placeholders = ",".join(["%s"] * len(wearables_imeis))
                attr_placeholders = ",".join(["%s"] * len(WEARABLE_REPORT_ATTR_NAMES))
                result = conn.execute(f"""
                    SELECT imei, attr_name, attr_value, sign_time
                    FROM iot_device_latest_metrics
                    WHERE imei IN ({placeholders})
                      AND attr_name IN ({attr_placeholders})
                    ORDER BY imei, attr_name
                """, [*wearables_imeis, *WEARABLE_REPORT_ATTR_NAMES])

                for imei, attr_name, attr_value, sign_time in result.fetchall():
                    if imei not in items_map:
                        items_map[imei] = []
                    items_map[imei].append({
                        "itemName": attr_name,
                        "itemValue": _format_report_metric_value(attr_name, attr_value),
                        "reportDate": sign_time.strftime("%Y-%m-%d %H:%M") if sign_time else None
                    })

            if radars_imeis:
                placeholders = ",".join(["%s"] * len(radars_imeis))
                # 查询统计范围内的报警数量
                result = conn.execute(f"""
                    SELECT imei, COUNT(*) as alarm_count
                    FROM iot_alarm_events
                    WHERE imei IN ({placeholders})
                      AND sign_time >= %s::DATE
                      AND sign_time < (%s::DATE + INTERVAL '1 day')
                    GROUP BY imei
                """, [*radars_imeis, event_start_date, event_end_date])

                for imei, alarm_count in result.fetchall():
                    alarm_map[imei] = alarm_count

                # 查询统计范围内的心跳事件上报数量
                result = conn.execute(f"""
                    SELECT imei, COUNT(*) as event_count
                    FROM iot_heartbeat_events
                    WHERE imei IN ({placeholders})
                      AND sign_time >= %s::DATE
                      AND sign_time < (%s::DATE + INTERVAL '1 day')
                    GROUP BY imei
                """, [*radars_imeis, event_start_date, event_end_date])

                for imei, event_count in result.fetchall():
                    event_count_map[imei] = event_count

            if sleep_radars_imeis:
                placeholders = ",".join(["%s"] * len(sleep_radars_imeis))
                attr_placeholders = ",".join(["%s"] * len(SLEEP_RADAR_REPORT_ATTR_NAMES))
                result = conn.execute(f"""
                    SELECT imei, attr_name, attr_value, attr_value_text, sign_time
                    FROM iot_device_latest_metrics
                    WHERE imei IN ({placeholders})
                      AND attr_name IN ({attr_placeholders})
                    ORDER BY imei, sign_time DESC NULLS LAST, attr_name
                """, [*sleep_radars_imeis, *SLEEP_RADAR_REPORT_ATTR_NAMES])

                radar_items_by_name = {}
                for imei, attr_name, attr_value, attr_value_text, sign_time in result.fetchall():
                    item_name = SLEEP_RADAR_REPORT_DISPLAY_NAMES.get(attr_name, attr_name)
                    items_by_name = radar_items_by_name.setdefault(imei, {})
                    if item_name in items_by_name:
                        continue
                    items_by_name[item_name] = {
                        "itemName": item_name,
                        "itemValue": _format_latest_metric_value(attr_name, attr_value, attr_value_text),
                        "reportDate": sign_time.strftime("%Y-%m-%d %H:%M") if sign_time else None
                    }

                radar_sort_order = {
                    name: index for index, name in enumerate(SLEEP_RADAR_REPORT_ITEM_ORDER)
                }
                for imei, items_by_name in radar_items_by_name.items():
                    radar_items_map[imei] = sorted(
                        items_by_name.values(),
                        key=lambda item: radar_sort_order.get(item["itemName"], 999),
                    )

            # 3. 组装返回数据
            state_map = {0: "正常", 1: "故障", 2: "报警", 4: "离线", 8: "隐患"}
            sort_order = {name: index for index, name in enumerate(WEARABLE_REPORT_ATTR_NAMES)}
            devices_data = []

            for row in device_rows:
                db_device_id, device_imei, device_type, device_version, room_name, device_state, sign_time = row
                device_type = _normalize_device_type_by_model(device_type, device_version)

                if device_type is None:
                    continue  # 设备信息不存在

                if device_imei in items_map:
                    items_map[device_imei].sort(key=lambda item: sort_order.get(item["itemName"], 999))

                device_info = {
                    "deviceId": db_device_id,
                    "deviceImei": device_imei,
                    "deviceType": device_type,
                    "deviceVersion": device_version,
                    "state": state_map.get(device_state, "未知") if device_state is not None else "未知",
                    "roomName": room_name,
                    "reportDate": sign_time.strftime("%Y-%m-%d %H:%M") if sign_time else None,
                }

                # 根据设备类型添加不同字段
                if device_type in ("智能手环", "智能手表"):
                    # 手环/手表：返回属性列表
                    if device_imei in items_map:
                        device_info["items"] = items_map[device_imei]
                elif device_type in ("跌倒雷达", "睡眠雷达"):
                    # 雷达：返回统计范围内报警数量和事件上报数量
                    device_info["alarmCount"] = str(alarm_map.get(device_imei, 0))
                    device_info["eventCount"] = str(event_count_map.get(device_imei, 0))
                    if device_type == "睡眠雷达":
                        device_info["items"] = radar_items_map.get(device_imei, [])

                devices_data.append(device_info)

            return devices_data

    try:
        devices_data = await asyncio.to_thread(_query_report)
        return ApiResponse(
            code="OK",
            success=True,
            message={"data": devices_data}
        )
    except Exception as e:
        logger.error(f"查询设备报告失败: {e}")
        return ApiResponse(
            code="ERROR",
            success=False,
            message={"msg": f"查询失败: {str(e)}"}
        )
