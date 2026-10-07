"""
IoT 数据库连接模块
使用 psycopg3 连接 PostgreSQL
"""
import json
import os
import re
import time
from datetime import datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

import psycopg
from contextlib import contextmanager
from dotenv import load_dotenv
from loguru import logger

try:
    from psycopg_pool import ConnectionPool
except ImportError:  # pragma: no cover - production dependency, keep local fallback.
    ConnectionPool = None


ENV_PATH = Path(__file__).resolve().parents[1] / ".env"
load_dotenv(ENV_PATH)


def _normalize_postgres_url(database_url: str) -> str:
    """Convert SQLAlchemy asyncpg URLs to psycopg-compatible PostgreSQL URLs."""
    database_url = database_url.strip()
    if database_url.startswith("postgresql+asyncpg://"):
        return "postgresql://" + database_url[len("postgresql+asyncpg://"):]
    if database_url.startswith("postgres+asyncpg://"):
        return "postgres://" + database_url[len("postgres+asyncpg://"):]
    return database_url


def _resolve_db_dsn() -> str:
    """Resolve IoT DB connection from .env instead of hardcoded local credentials."""
    configured_url = (
        os.getenv("IOT_DATABASE_URL", "").strip()
        or os.getenv("IOT_DB_DSN", "").strip()
        or os.getenv("DATABASE_URL", "").strip()
    )
    if not configured_url:
        raise RuntimeError("请在 .env 中配置 DATABASE_URL 或 IOT_DATABASE_URL")
    return _normalize_postgres_url(configured_url)


DB_DSN = _resolve_db_dsn()

IOT_DB_POOL_MIN_SIZE = int(os.getenv("IOT_DB_POOL_MIN_SIZE", "1"))
IOT_DB_POOL_MAX_SIZE = int(os.getenv("IOT_DB_POOL_MAX_SIZE", "10"))
IOT_FILE_BATCH_SIZE = int(os.getenv("IOT_FILE_BATCH_SIZE", "200"))
IOT_FILE_BATCH_SECONDS = int(os.getenv("IOT_FILE_BATCH_SECONDS", "20"))
IOT_DEVICE_CACHE_TTL_SECONDS = int(os.getenv("IOT_DEVICE_CACHE_TTL_SECONDS", "3600"))
IOT_DEVICE_NEGATIVE_CACHE_TTL_SECONDS = int(os.getenv("IOT_DEVICE_NEGATIVE_CACHE_TTL_SECONDS", "300"))
IOT_BOUND_FILTER_ENABLED = os.getenv("IOT_BOUND_FILTER_ENABLED", "true").strip().lower() not in {"0", "false", "no"}

HEALTH_METRIC_ATTR_NAMES = {"心率", "血氧", "舒张压", "收缩压", "温度", "计步"}
HEALTH_EVENT_NAMES = {"温度数据上报", "健康数据上报", "计步和睡眠翻滚数据上报"}
SM_C03_SLEEP_RADAR_HEALTH_EVENT_NAMES = {"呼吸心率信息上报", "设备存在信息上报"}
SM_C03_SLEEP_RADAR_PARAM_EVENT_NAME = "设备参数信息上报"
SM_C03_SLEEP_RADAR_ALARM_PARAM_EVENT_NAME = "报警参数配置信息上报"
RT_C03AI_FALL_RADAR_PARAM_EVENT_NAME = "设备参数信息上报"
SM_C03_SLEEP_RADAR_PARAM_ATTRS = {
    "工作模式": ("360", "detectionMode", "detection_mode"),
    "心率开关": ("360", "heartRateSwitch", "switch"),
    "呼吸开关": ("360", "breathingSwitch", "switch"),
    "睡眠开关": ("360", "sleepSwitch", "switch"),
    "长时间无人计时开关": ("360", "longTimeNoTimerSwitch", "switch"),
    "无人计时时长设置": ("360", "unmanneDuration", "duration"),
    "存在开关": ("360", "existSwitch", "switch"),
    "异常挣扎开关": ("360", "abnormalStruggleSwitch", "switch"),
}
SM_C03_SLEEP_RADAR_ALARM_PARAM_ATTRS = {
    "报警提示音开关": ("381", "promptTone", "switch"),
    "提示音开关": ("381", "promptTone", "switch"),
    "防拆报警开关": ("381", "FC_ALM_SW", "switch"),
    "拉绳报警开关": ("381", "LS_ALM_SW", "switch"),
    "连续心率异常报警低阈值": ("381", "HEARTRATE_ALM_SW_LOW", "threshold"),
    "连续心率异常报警高阈值": ("381", "HEARTRATE_ALM_SW_HIGH", "threshold"),
    "连续心率异常报警持续时间": ("381", "HEARTRATE_ALM_SW_TIME", "seconds"),
    "连续呼吸异常报警低阈值": ("381", "BREATHING_ALM_SW_LOW", "threshold"),
    "连续呼吸异常报警高阈值": ("381", "BREATHING_ALM_SW_HIGH", "threshold"),
    "连续呼吸异常报警持续时间": ("381", "BREATHING_ALM_SW_TIME", "seconds"),
    "离床报警持续时间": ("381", "BED_ALM_SW_TIME", "minutes"),
    "无人报警持续时间": ("381", "UNMANNED_ALM_SW_TIME", "minutes"),
}
SM_C03_SLEEP_RADAR_ALARM_COMPOUND_ATTRS = {
    "连续心率异常报警开关": (
        "HEARTRATE_ALM_SW_SWITCH",
        {
            "低阈值": ("HEARTRATE_ALM_SW_LOW", "threshold"),
            "高阈值": ("HEARTRATE_ALM_SW_HIGH", "threshold"),
            "持续时间": ("HEARTRATE_ALM_SW_TIME", "seconds"),
        },
    ),
    "连续呼吸异常报警开关": (
        "BREATHING_ALM_SW_SWITCH",
        {
            "低阈值": ("BREATHING_ALM_SW_LOW", "threshold"),
            "高阈值": ("BREATHING_ALM_SW_HIGH", "threshold"),
            "持续时间": ("BREATHING_ALM_SW_TIME", "seconds"),
        },
    ),
    "离床报警开关": (
        "BED_ALM_SW_SWITCH",
        {"持续时间": ("BED_ALM_SW_TIME", "minutes")},
    ),
    "离床报警参数": (
        "BED_ALM_SW_SWITCH",
        {"持续时间": ("BED_ALM_SW_TIME", "minutes")},
    ),
    "无人报警开关": (
        "UNMANNED_ALM_SW_SWITCH",
        {"持续时间": ("UNMANNED_ALM_SW_TIME", "minutes")},
    ),
    "无人报警参数": (
        "UNMANNED_ALM_SW_SWITCH",
        {"持续时间": ("UNMANNED_ALM_SW_TIME", "minutes")},
    ),
}
RT_C03AI_FALL_RADAR_PARAM_ATTRS = {
    "有人报警开关": ("43", "someoneAlmSwitch", "switch"),
    "无人报警开关": ("43", "unmannedAlmSwitch", "switch"),
    "跌倒高度": ("43", "fall_Height", "fall_height"),
}
SM_C03_DETECTION_MODE_VALUE_MAP = {
    "0": "0",
    "实时探测": "0",
    "实时探测模式": "0",
    "1": "1",
    "睡眠探测": "1",
    "睡眠探测模式": "1",
}
SWITCH_VALUE_MAP = {
    "0": "0",
    "关": "0",
    "关闭": "0",
    "false": "0",
    "False": "0",
    "1": "1",
    "开": "1",
    "开启": "1",
    "true": "1",
    "True": "1",
}
NUMERIC_PATTERN = re.compile(r"[-+]?[0-9]+(?:[.][0-9]+)?")
EVENT_INSERT_TABLES = {
    "iot_health_events",
    "iot_alarm_events",
    "iot_heartbeat_events",
}
ITEM_INSERT_TABLES = {
    "iot_health_event_items",
    "iot_alarm_event_items",
    "iot_heartbeat_event_items",
}

_pool = None
_device_snapshot_cache: dict[str, tuple[float, dict | None]] = {}


@contextmanager
def get_connection():
    """获取数据库连接。优先使用连接池，依赖缺失时降级为按需创建。"""
    global _pool
    pooled = _pool is not None
    if pooled:
        conn_ctx = _pool.connection()
        conn = conn_ctx.__enter__()
    else:
        conn_ctx = None
        conn = psycopg.connect(DB_DSN)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        if pooled:
            conn_ctx.__exit__(None, None, None)
        else:
            conn.close()


def init_pool():
    """初始化 IoT 数据库连接池并验证数据库可连接。"""
    global _pool
    try:
        if ConnectionPool is not None and _pool is None:
            _pool = ConnectionPool(
                conninfo=DB_DSN,
                min_size=IOT_DB_POOL_MIN_SIZE,
                max_size=IOT_DB_POOL_MAX_SIZE,
                open=True,
            )
            logger.info(
                "IoT database connection pool initialized: "
                f"min={IOT_DB_POOL_MIN_SIZE}, max={IOT_DB_POOL_MAX_SIZE}"
            )
        elif ConnectionPool is None:
            logger.warning("psycopg_pool is not installed, IoT DB falls back to per-call connections")

        with get_connection() as conn:
            conn.execute("SELECT 1")
            ensure_file_offsets_table(conn)
            ensure_device_table_columns(conn)
            ensure_user_devices_indexes(conn)
            ensure_device_params_table(conn)
            ensure_metric_trend_indexes(conn)
            ensure_performance_tables(conn)
        logger.info("IoT database connection verified")
    except Exception as e:
        logger.error(f"Failed to connect IoT database: {e}")
        raise


def close_pool():
    """关闭 IoT 数据库连接池。"""
    global _pool
    if _pool is not None:
        _pool.close()
        _pool = None


def ensure_file_offsets_table(conn) -> None:
    """Ensure the persistent file checkpoint table exists."""
    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_file_offsets (
            file_path TEXT PRIMARY KEY,
            offset_bytes BIGINT NOT NULL DEFAULT 0 CHECK (offset_bytes >= 0),
            file_size BIGINT NOT NULL DEFAULT 0 CHECK (file_size >= 0),
            status VARCHAR(16) NOT NULL DEFAULT 'processing',
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            completed_at TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_file_offsets_status_updated_at
        ON iot_file_offsets (status, updated_at)
    """)


def _table_exists(conn, table_name: str) -> bool:
    row = conn.execute("SELECT to_regclass(%s)", (f"public.{table_name}",)).fetchone()
    return bool(row and row[0] is not None)


def ensure_device_table_columns(conn) -> None:
    """Ensure columns used by the device add endpoint exist in legacy databases."""
    if not _table_exists(conn, "iot_devices"):
        logger.warning("iot_devices table does not exist, skip IoT device column checks")
        return

    conn.execute("ALTER TABLE iot_devices ADD COLUMN IF NOT EXISTS device_model_id BIGINT")
    conn.execute("ALTER TABLE iot_devices ADD COLUMN IF NOT EXISTS room_name VARCHAR(128)")


def ensure_user_devices_indexes(conn) -> None:
    """Ensure indexes used by user-device binding lookups exist."""
    if not _table_exists(conn, "iot_user_devices"):
        logger.warning("iot_user_devices table does not exist, skip user-device index creation")
        return

    conn.execute("""
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1
                FROM pg_class c
                JOIN pg_index i ON i.indexrelid = c.oid
                JOIN pg_namespace n ON n.oid = c.relnamespace
                WHERE n.nspname = 'public'
                  AND c.relname = 'idx_iot_user_devices_user_device_imei'
                  AND NOT i.indisunique
            ) THEN
                DROP INDEX public.idx_iot_user_devices_user_device_imei;
            END IF;
        END $$;
    """)
    conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_iot_user_devices_user_device_imei
        ON iot_user_devices (user_id, device_id, device_imei)
    """)


def ensure_device_params_table(conn) -> None:
    """Ensure the device parameter configuration table exists."""
    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_device_params (
            id BIGSERIAL PRIMARY KEY,
            imei VARCHAR(32) NOT NULL REFERENCES iot_devices(imei),
            param_code VARCHAR(32) NOT NULL,
            field_name VARCHAR(32) NOT NULL DEFAULT '',
            param_value VARCHAR(64),
            create_by VARCHAR(32) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_iot_device_params_imei_code_field
        ON iot_device_params (imei, param_code, field_name)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_device_params_imei
        ON iot_device_params (imei)
    """)


def ensure_metric_trend_indexes(conn) -> None:
    """Ensure indexes used by the metric trend endpoint exist."""
    exists = conn.execute("""
        SELECT to_regclass('public.iot_health_event_items'),
               to_regclass('public.iot_user_devices')
    """).fetchone()
    health_event_items_exists = exists and exists[0] is not None
    user_devices_exists = exists and exists[1] is not None

    if health_event_items_exists:
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_iot_health_items_imei_attr_sign_id
            ON iot_health_event_items (imei, attr_name, sign_time DESC, id DESC)
        """)
    else:
        logger.warning("iot_health_event_items table does not exist, skip metric trend index creation")

    if user_devices_exists:
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_iot_user_devices_user_imei_status
            ON iot_user_devices (user_id, device_imei, status)
        """)
    else:
        logger.warning("iot_user_devices table does not exist, skip user-device trend index creation")


def ensure_performance_tables(conn) -> None:
    """Ensure performance optimization tables and indexes exist."""
    if not _table_exists(conn, "iot_devices"):
        logger.warning("iot_devices table does not exist, skip IoT performance table creation")
        return

    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_health_events (
            id BIGSERIAL PRIMARY KEY,
            imei VARCHAR(32) NOT NULL REFERENCES iot_devices(imei),
            event_name VARCHAR(64),
            data_type SMALLINT,
            device_state SMALLINT,
            sign_time TIMESTAMP,
            signature VARCHAR(64),
            nonce VARCHAR(32),
            raw_data TEXT,
            handler_status SMALLINT NOT NULL DEFAULT 0,
            handle_time TIMESTAMP,
            alarm_reason VARCHAR(128),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_alarm_events (
            id BIGSERIAL PRIMARY KEY,
            imei VARCHAR(32) NOT NULL REFERENCES iot_devices(imei),
            event_name VARCHAR(64),
            data_type SMALLINT,
            device_state SMALLINT,
            sign_time TIMESTAMP,
            signature VARCHAR(64),
            nonce VARCHAR(32),
            raw_data TEXT,
            handler_status SMALLINT NOT NULL DEFAULT 0,
            handle_time TIMESTAMP,
            alarm_reason VARCHAR(128),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_heartbeat_events (
            id BIGSERIAL PRIMARY KEY,
            imei VARCHAR(32) NOT NULL REFERENCES iot_devices(imei),
            event_name VARCHAR(64),
            data_type SMALLINT,
            device_state SMALLINT,
            sign_time TIMESTAMP,
            signature VARCHAR(64),
            nonce VARCHAR(32),
            raw_data TEXT,
            handler_status SMALLINT NOT NULL DEFAULT 0,
            handle_time TIMESTAMP,
            alarm_reason VARCHAR(128),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_health_event_items (
            id BIGSERIAL PRIMARY KEY,
            event_id BIGINT NOT NULL REFERENCES iot_health_events(id),
            imei VARCHAR(32) NOT NULL REFERENCES iot_devices(imei),
            attr_name VARCHAR(64),
            attr_value DOUBLE PRECISION,
            prop_value VARCHAR(128),
            sign_time TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_alarm_event_items (
            id BIGSERIAL PRIMARY KEY,
            event_id BIGINT NOT NULL REFERENCES iot_alarm_events(id),
            imei VARCHAR(32) NOT NULL REFERENCES iot_devices(imei),
            attr_name VARCHAR(64),
            attr_value VARCHAR(128),
            sign_time TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_heartbeat_event_items (
            id BIGSERIAL PRIMARY KEY,
            event_id BIGINT NOT NULL REFERENCES iot_heartbeat_events(id),
            imei VARCHAR(32) NOT NULL REFERENCES iot_devices(imei),
            attr_name VARCHAR(64),
            attr_value VARCHAR(128),
            sign_time TIMESTAMP,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_device_latest_metrics (
            id BIGSERIAL PRIMARY KEY,
            imei VARCHAR(32) NOT NULL REFERENCES iot_devices(imei),
            attr_name VARCHAR(64),
            attr_value DOUBLE PRECISION,
            attr_value_text VARCHAR(128),
            sign_time TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS iot_ingest_performance (
            id BIGSERIAL PRIMARY KEY,
            run_id VARCHAR(80),
            trace_id VARCHAR(128),
            seq BIGINT,
            imei VARCHAR(32),
            event_name VARCHAR(64),
            event_kind VARCHAR(64),
            signature VARCHAR(64),
            client_send_ms DOUBLE PRECISION,
            api_received_ms DOUBLE PRECISION,
            file_write_ms DOUBLE PRECISION,
            file_read_ms DOUBLE PRECISION,
            db_write_ms DOUBLE PRECISION NOT NULL,
            file_path TEXT,
            file_offset_bytes BIGINT,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
    """)

    conn.execute("ALTER TABLE iot_alarm_events ADD COLUMN IF NOT EXISTS handler_status SMALLINT NOT NULL DEFAULT 0")
    conn.execute("ALTER TABLE iot_alarm_events ADD COLUMN IF NOT EXISTS handle_time TIMESTAMP")
    conn.execute("ALTER TABLE iot_alarm_events ADD COLUMN IF NOT EXISTS alarm_reason VARCHAR(128)")
    conn.execute("ALTER TABLE iot_heartbeat_events ADD COLUMN IF NOT EXISTS handler_status SMALLINT NOT NULL DEFAULT 0")
    conn.execute("ALTER TABLE iot_heartbeat_events ADD COLUMN IF NOT EXISTS handle_time TIMESTAMP")
    conn.execute("ALTER TABLE iot_heartbeat_events ADD COLUMN IF NOT EXISTS alarm_reason VARCHAR(128)")
    conn.execute("ALTER TABLE iot_health_event_items ADD COLUMN IF NOT EXISTS prop_value VARCHAR(128)")
    conn.execute("ALTER TABLE iot_device_latest_metrics ADD COLUMN IF NOT EXISTS attr_value_text VARCHAR(128)")

    conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS uq_iot_health_events_signature
        ON iot_health_events (signature)
        WHERE signature IS NOT NULL
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_health_events_imei_sign_time
        ON iot_health_events (imei, sign_time DESC, id DESC)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_health_events_sign_time
        ON iot_health_events (sign_time DESC)
    """)

    conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS uq_iot_alarm_events_signature
        ON iot_alarm_events (signature)
        WHERE signature IS NOT NULL
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_alarm_events_imei_sign_time
        ON iot_alarm_events (imei, sign_time DESC, id DESC)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_alarm_events_data_type_time
        ON iot_alarm_events (data_type, sign_time DESC)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_alarm_events_device_state_time
        ON iot_alarm_events (device_state, sign_time DESC)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_alarm_events_type_state_time
        ON iot_alarm_events (data_type, device_state, sign_time DESC)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_alarm_events_handler_status_time
        ON iot_alarm_events (handler_status, sign_time DESC)
    """)

    conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS uq_iot_heartbeat_events_signature
        ON iot_heartbeat_events (signature)
        WHERE signature IS NOT NULL
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_heartbeat_events_imei_sign_time
        ON iot_heartbeat_events (imei, sign_time DESC, id DESC)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_heartbeat_events_sign_time
        ON iot_heartbeat_events (sign_time DESC)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_heartbeat_events_imei_status_time
        ON iot_heartbeat_events (imei, handler_status, sign_time DESC, id DESC)
    """)

    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_health_items_imei_attr_sign_id
        ON iot_health_event_items (imei, attr_name, sign_time DESC, id DESC)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_health_items_event_id
        ON iot_health_event_items (event_id)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_health_items_attr_sign_time
        ON iot_health_event_items (attr_name, sign_time DESC)
    """)

    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_alarm_items_event_id
        ON iot_alarm_event_items (event_id)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_alarm_items_imei_attr_sign_id
        ON iot_alarm_event_items (imei, attr_name, sign_time DESC, id DESC)
    """)

    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_heartbeat_items_event_id
        ON iot_heartbeat_event_items (event_id)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_heartbeat_items_imei_attr_sign_id
        ON iot_heartbeat_event_items (imei, attr_name, sign_time DESC, id DESC)
    """)

    conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS uq_iot_latest_metrics_imei_attr
        ON iot_device_latest_metrics (imei, attr_name)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_latest_metrics_attr_time
        ON iot_device_latest_metrics (attr_name, sign_time DESC)
    """)
    conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS uq_iot_ingest_performance_signature
        ON iot_ingest_performance (signature)
        WHERE signature IS NOT NULL
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_ingest_performance_run_id
        ON iot_ingest_performance (run_id)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_iot_ingest_performance_imei_created
        ON iot_ingest_performance (imei, created_at DESC)
    """)


# ========== 统一的数据写入逻辑 ==========

def _parse_datetime(s: str):
    """统一时间解析：支持多种格式"""
    if not s:
        return None
    for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S", "%Y/%m/%d %H:%M:%S"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            continue
    return None


def _parse_numeric(value) -> float | None:
    """Parse platform metric values into float for typed health tables."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, Decimal):
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    match = NUMERIC_PATTERN.fullmatch(text)
    if not match:
        return None
    try:
        return float(Decimal(match.group(0)))
    except (InvalidOperation, ValueError):
        return None


def _parse_float(value) -> float | None:
    if value in (None, ""):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _parse_int(value) -> int | None:
    if value in (None, ""):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _extract_perf(data: dict) -> dict:
    perf = data.get("_perf")
    return perf if isinstance(perf, dict) else {}


def _cache_get(key: str) -> dict | None:
    cached = _device_snapshot_cache.get(key)
    if cached is None:
        return None
    expires_at, value = cached
    if expires_at < time.time():
        _device_snapshot_cache.pop(key, None)
        return None
    return value


def _cache_set(key: str, value: dict | None, ttl_seconds: int = IOT_DEVICE_CACHE_TTL_SECONDS) -> None:
    _device_snapshot_cache[key] = (time.time() + max(1, ttl_seconds), value)


def clear_device_snapshot_cache(imei: str | None = None) -> None:
    """Clear IoT device snapshot cache for binding/device changes."""
    if imei:
        _device_snapshot_cache.pop(imei, None)
        return
    _device_snapshot_cache.clear()


def _normalize_text(value) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text if text else None


def _health_item_value_parts(value) -> tuple[float | None, str | None, str | None]:
    attr_value_text = _normalize_text(value)
    numeric_value = _parse_numeric(value)
    prop_value = None if numeric_value is not None else attr_value_text
    return numeric_value, prop_value, attr_value_text


def _normalize_numeric_text(value) -> str | None:
    if value is None or value == "":
        return None
    text = str(value).strip()
    return text if text else None


def _is_sm_c03_sleep_radar_health_event(data: dict, current_snapshot: dict | None = None) -> bool:
    current_snapshot = current_snapshot or {}
    event_name = str(data.get("eventName") or "").strip()
    device_type = str(current_snapshot.get("device_type") or data.get("deviceType") or "").strip()
    device_version = str(current_snapshot.get("device_version") or data.get("deviceVersion") or "").strip()

    return (
        device_type == "睡眠雷达"
        and device_version == "SM-C03"
        and event_name in SM_C03_SLEEP_RADAR_HEALTH_EVENT_NAMES
    )


def _is_sm_c03_sleep_radar_param_event(data: dict, current_snapshot: dict | None = None) -> bool:
    current_snapshot = current_snapshot or {}
    event_name = str(data.get("eventName") or "").strip()
    device_type = str(current_snapshot.get("device_type") or data.get("deviceType") or "").strip()
    device_version = str(current_snapshot.get("device_version") or data.get("deviceVersion") or "").strip()

    return (
        device_type == "睡眠雷达"
        and device_version == "SM-C03"
        and event_name == SM_C03_SLEEP_RADAR_PARAM_EVENT_NAME
    )


def _is_sm_c03_sleep_radar_alarm_param_event(data: dict, current_snapshot: dict | None = None) -> bool:
    current_snapshot = current_snapshot or {}
    event_name = str(data.get("eventName") or "").strip()
    device_type = str(current_snapshot.get("device_type") or data.get("deviceType") or "").strip()
    device_version = str(current_snapshot.get("device_version") or data.get("deviceVersion") or "").strip()

    return (
        device_type == "睡眠雷达"
        and device_version == "SM-C03"
        and event_name == SM_C03_SLEEP_RADAR_ALARM_PARAM_EVENT_NAME
    )


def _is_rt_c03ai_fall_radar_param_event(data: dict, current_snapshot: dict | None = None) -> bool:
    current_snapshot = current_snapshot or {}
    event_name = str(data.get("eventName") or "").strip()
    device_type = str(current_snapshot.get("device_type") or data.get("deviceType") or "").strip()
    device_version = str(current_snapshot.get("device_version") or data.get("deviceVersion") or "").strip()

    return (
        device_type == "跌倒雷达"
        and device_version == "RT-C03AI"
        and event_name == RT_C03AI_FALL_RADAR_PARAM_EVENT_NAME
    )


def _normalize_sm_c03_param_value(attr_name: str, value, value_type: str) -> str | None:
    text = _normalize_text(value)
    if text is None:
        return None

    if value_type == "detection_mode":
        normalized = SM_C03_DETECTION_MODE_VALUE_MAP.get(text)
        if normalized is None:
            logger.warning(f"Skip SM-C03 sleep radar param with invalid detection mode: {attr_name}={text}")
        return normalized

    if value_type == "switch":
        normalized = SWITCH_VALUE_MAP.get(text) or SWITCH_VALUE_MAP.get(text.lower())
        if normalized is None:
            logger.warning(f"Skip SM-C03 sleep radar param with invalid switch value: {attr_name}={text}")
        return normalized

    if value_type == "duration":
        match = NUMERIC_PATTERN.search(text)
        if not match:
            logger.warning(f"Skip SM-C03 sleep radar param with invalid duration: {attr_name}={text}")
            return None
        try:
            duration_decimal = Decimal(match.group(0))
        except InvalidOperation:
            logger.warning(f"Skip SM-C03 sleep radar param with invalid duration: {attr_name}={text}")
            return None
        if duration_decimal != duration_decimal.to_integral_value():
            logger.warning(f"Skip SM-C03 sleep radar param non-integer duration: {attr_name}={text}")
            return None
        duration = int(duration_decimal)
        if duration < 30 or duration > 180:
            logger.warning(f"Skip SM-C03 sleep radar param duration out of range: {attr_name}={text}")
            return None
        return str(duration)

    return text


def _normalize_sm_c03_switch_text(attr_name: str, value) -> str | None:
    text = _normalize_text(value)
    if text is None:
        return None

    normalized = SWITCH_VALUE_MAP.get(text) or SWITCH_VALUE_MAP.get(text.lower())
    if normalized is not None:
        return normalized

    first_segment = re.split(r"[、,，;\s]+", text, maxsplit=1)[0].strip()
    normalized = SWITCH_VALUE_MAP.get(first_segment) or SWITCH_VALUE_MAP.get(first_segment.lower())
    if normalized is not None:
        return normalized

    for label in ("开启", "关闭", "开", "关"):
        if label in text:
            return SWITCH_VALUE_MAP[label]

    logger.warning(f"Skip reported device param with invalid switch value: {attr_name}={text}")
    return None


def _parse_integer_text(attr_name: str, value, min_value: int, max_value: int) -> str | None:
    text = _normalize_text(value)
    if text is None:
        return None

    match = NUMERIC_PATTERN.search(text)
    if not match:
        logger.warning(f"Skip reported device param with invalid integer value: {attr_name}={text}")
        return None

    try:
        parsed = Decimal(match.group(0))
    except InvalidOperation:
        logger.warning(f"Skip reported device param with invalid integer value: {attr_name}={text}")
        return None

    if parsed != parsed.to_integral_value():
        logger.warning(f"Skip reported device param non-integer value: {attr_name}={text}")
        return None

    value_int = int(parsed)
    if value_int < min_value or value_int > max_value:
        logger.warning(f"Skip reported device param out of range: {attr_name}={text}")
        return None

    return str(value_int)


def _normalize_sm_c03_alarm_param_value(attr_name: str, value, value_type: str) -> str | None:
    if value_type == "switch":
        return _normalize_sm_c03_switch_text(attr_name, value)
    if value_type == "threshold":
        return _parse_integer_text(attr_name, value, 0, 200)
    if value_type == "seconds":
        return _parse_integer_text(attr_name, value, 0, 3600)
    if value_type == "minutes":
        return _parse_integer_text(attr_name, value, 0, 1440)
    return _normalize_text(value)


def _normalize_rt_c03ai_fall_param_value(attr_name: str, value, value_type: str) -> str | None:
    if value_type == "switch":
        return _normalize_sm_c03_switch_text(attr_name, value)
    if value_type == "fall_height":
        return _parse_integer_text(attr_name, value, 10, 100)
    return _normalize_text(value)


def _parse_labeled_integer_text(
    attr_name: str,
    value,
    label: str,
    value_type: str,
) -> str | None:
    text = _normalize_text(value)
    if text is None:
        return None

    match = re.search(
        rf"{re.escape(label)}[）)]?[：:\s]*({NUMERIC_PATTERN.pattern})",
        text,
    )
    if not match:
        return None

    return _normalize_sm_c03_alarm_param_value(attr_name, match.group(1), value_type)


def _build_sm_c03_alarm_compound_param_rows(
    imei: str,
    attr_name: str,
    value,
) -> list[tuple[str, str, str, str, str]]:
    spec = SM_C03_SLEEP_RADAR_ALARM_COMPOUND_ATTRS.get(attr_name)
    if spec is None:
        return []

    switch_field_name, labeled_fields = spec
    rows = []

    switch_value = _normalize_sm_c03_switch_text(attr_name, value)
    if switch_value is not None:
        rows.append((imei, "381", switch_field_name, switch_value, "device_report"))

    for label, (field_name, value_type) in labeled_fields.items():
        param_value = _parse_labeled_integer_text(attr_name, value, label, value_type)
        if param_value is not None:
            rows.append((imei, "381", field_name, param_value, "device_report"))

    return rows


def _build_sm_c03_sleep_radar_param_rows(
    imei: str,
    data: dict,
    current_snapshot: dict | None = None,
) -> list[tuple[str, str, str, str, str]]:
    is_device_param_event = _is_sm_c03_sleep_radar_param_event(data, current_snapshot)
    is_alarm_param_event = _is_sm_c03_sleep_radar_alarm_param_event(data, current_snapshot)
    if not is_device_param_event and not is_alarm_param_event:
        return []

    rows = []
    for item in data.get("items", []) or []:
        attr_name = _normalize_text(item.get("attrName"))
        if not attr_name:
            continue

        if is_alarm_param_event:
            compound_rows = _build_sm_c03_alarm_compound_param_rows(imei, attr_name, item.get("value"))
            if compound_rows:
                rows.extend(compound_rows)
                continue

        mapping = (
            SM_C03_SLEEP_RADAR_PARAM_ATTRS.get(attr_name)
            if is_device_param_event
            else SM_C03_SLEEP_RADAR_ALARM_PARAM_ATTRS.get(attr_name)
        )
        if mapping is None:
            continue

        param_code, field_name, value_type = mapping
        if is_alarm_param_event:
            param_value = _normalize_sm_c03_alarm_param_value(attr_name, item.get("value"), value_type)
        else:
            param_value = _normalize_sm_c03_param_value(attr_name, item.get("value"), value_type)
        if param_value is None:
            continue

        rows.append((imei, param_code, field_name, param_value, "device_report"))

    return rows


def _build_rt_c03ai_fall_radar_param_rows(
    imei: str,
    data: dict,
    current_snapshot: dict | None = None,
) -> list[tuple[str, str, str, str, str]]:
    if not _is_rt_c03ai_fall_radar_param_event(data, current_snapshot):
        return []

    rows = []
    for item in data.get("items", []) or []:
        attr_name = _normalize_text(item.get("attrName"))
        if not attr_name:
            continue

        mapping = RT_C03AI_FALL_RADAR_PARAM_ATTRS.get(attr_name)
        if mapping is None:
            continue

        param_code, field_name, value_type = mapping
        param_value = _normalize_rt_c03ai_fall_param_value(attr_name, item.get("value"), value_type)
        if param_value is None:
            continue

        rows.append((imei, param_code, field_name, param_value, "device_report"))

    return rows


def _build_reported_device_param_rows(
    imei: str,
    data: dict,
    current_snapshot: dict | None = None,
) -> list[tuple[str, str, str, str, str]]:
    rows = []
    rows.extend(_build_sm_c03_sleep_radar_param_rows(imei, data, current_snapshot))
    rows.extend(_build_rt_c03ai_fall_radar_param_rows(imei, data, current_snapshot))
    return rows


def _normalize_contacts(contact_list) -> list[dict]:
    contacts = []
    for contact in contact_list or []:
        phone = _normalize_text(contact.get("phonenumber") or contact.get("phone"))
        if not phone:
            continue
        contacts.append({
            "name": _normalize_text(contact.get("name")),
            "phone": phone,
            "contact_type": contact.get("contactType") or contact.get("contact_type"),
        })
    contacts.sort(key=lambda item: (item["phone"], str(item.get("contact_type") or ""), item.get("name") or ""))
    return contacts


def _device_snapshot_from_data(data: dict) -> dict:
    return {
        "iccid": _normalize_text(data.get("iccid")),
        "device_type": _normalize_text(data.get("deviceType")),
        "device_version": _normalize_text(data.get("deviceVersion")),
        "device_state": data.get("deviceState"),
        "longitude": _normalize_numeric_text(data.get("longitude")),
        "latitude": _normalize_numeric_text(data.get("latitude")),
        "site": _normalize_text(data.get("site")),
        "company_name": _normalize_text(data.get("companyName") or data.get("conpanyName")),
        "enabled_time": data.get("enabledTime"),
        "contacts": _normalize_contacts(data.get("contactList")),
    }


def _device_snapshot_from_db(device_row, contact_rows) -> dict:
    return {
        "iccid": _normalize_text(device_row[1]),
        "device_type": _normalize_text(device_row[2]),
        "device_version": _normalize_text(device_row[3]),
        "device_state": device_row[4],
        "longitude": _normalize_numeric_text(device_row[5]),
        "latitude": _normalize_numeric_text(device_row[6]),
        "site": _normalize_text(device_row[7]),
        "company_name": _normalize_text(device_row[8]),
        "enabled_time": device_row[9].strftime("%Y-%m-%d %H:%M:%S") if device_row[9] else None,
        "contacts": [
            {
                "name": _normalize_text(row[0]),
                "phone": _normalize_text(row[1]),
                "contact_type": row[2],
            }
            for row in contact_rows
            if _normalize_text(row[1])
        ],
    }


def _snapshots_equal(current: dict, incoming: dict) -> bool:
    for key in (
        "iccid",
        "device_type",
        "device_version",
        "device_state",
        "longitude",
        "latitude",
        "site",
        "company_name",
        "enabled_time",
        "contacts",
    ):
        incoming_value = incoming.get(key)
        if incoming_value in (None, "") and key != "contacts":
            continue
        if current.get(key) != incoming_value:
            return False
    return True


def _load_bound_device_snapshot(conn, imei: str) -> dict | None:
    if not IOT_BOUND_FILTER_ENABLED:
        row = conn.execute("""
            SELECT id, iccid, device_type, device_version, device_state,
                   longitude, latitude, site, company_name, enabled_time
            FROM iot_devices
            WHERE imei = %s
            LIMIT 1
        """, (imei,)).fetchone()
    else:
        row = conn.execute("""
            SELECT d.id, d.iccid, d.device_type, d.device_version, d.device_state,
                   d.longitude, d.latitude, d.site, d.company_name, d.enabled_time
            FROM iot_devices d
            WHERE d.imei = %s
              AND EXISTS (
                  SELECT 1
                  FROM iot_user_devices ud
                  WHERE ud.device_imei = d.imei
                    AND ud.status = 1
              )
            LIMIT 1
        """, (imei,)).fetchone()

    if row is None:
        _cache_set(imei, None, IOT_DEVICE_NEGATIVE_CACHE_TTL_SECONDS)
        return None

    contact_rows = conn.execute("""
        SELECT name, phone, contact_type
        FROM iot_device_contacts
        WHERE imei = %s
        ORDER BY phone, contact_type, name
    """, (imei,)).fetchall()
    snapshot = _device_snapshot_from_db(row, contact_rows)
    snapshot["device_id"] = row[0]
    _cache_set(imei, snapshot)
    return snapshot


def get_bound_device_snapshot(conn, imei: str) -> dict | None:
    cached = _cache_get(imei)
    if cached is not None:
        return cached
    if imei in _device_snapshot_cache:
        return None
    return _load_bound_device_snapshot(conn, imei)


def is_bound_device_for_ingest(imei: str | None) -> bool:
    """Fast ingress check used before writing upload files."""
    if not imei:
        return False
    with get_connection() as conn:
        return get_bound_device_snapshot(conn, imei) is not None


def _sync_device_basics_if_changed(conn, imei: str, data: dict, current_snapshot: dict) -> None:
    incoming = _device_snapshot_from_data(data)
    if _snapshots_equal(current_snapshot, incoming):
        return

    conn.execute("""
        UPDATE iot_devices SET
            iccid = COALESCE(%s, iccid),
            device_type = COALESCE(%s, device_type),
            device_version = COALESCE(%s, device_version),
            device_state = COALESCE(%s, device_state),
            longitude = COALESCE(%s, longitude),
            latitude = COALESCE(%s, latitude),
            site = COALESCE(%s, site),
            company_name = COALESCE(%s, company_name),
            enabled_time = COALESCE(%s, enabled_time),
            updated_at = CURRENT_TIMESTAMP
        WHERE imei = %s
    """, (
        incoming.get("iccid"),
        incoming.get("device_type"),
        incoming.get("device_version"),
        incoming.get("device_state"),
        incoming.get("longitude"),
        incoming.get("latitude"),
        incoming.get("site"),
        incoming.get("company_name"),
        _parse_datetime(incoming.get("enabled_time")),
        imei,
    ))

    for contact in incoming.get("contacts", []):
        conn.execute("""
            INSERT INTO iot_device_contacts (imei, name, phone, contact_type)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (imei, phone) DO UPDATE SET
                name = COALESCE(EXCLUDED.name, iot_device_contacts.name),
                contact_type = COALESCE(EXCLUDED.contact_type, iot_device_contacts.contact_type)
        """, (
            imei,
            contact.get("name"),
            contact.get("phone"),
            contact.get("contact_type"),
        ))

    next_snapshot = dict(current_snapshot)
    for key, value in incoming.items():
        if value not in (None, "") or key == "contacts":
            next_snapshot[key] = value
    _cache_set(imei, next_snapshot)


def _event_categories(data: dict, current_snapshot: dict | None = None) -> list[str]:
    event_name = str(data.get("eventName") or "").strip()
    data_type = str(data.get("dataType") if data.get("dataType") is not None else "").strip()
    device_state = str(data.get("deviceState") if data.get("deviceState") is not None else "").strip()

    categories = []
    if event_name in HEALTH_EVENT_NAMES or _is_sm_c03_sleep_radar_health_event(data, current_snapshot):
        categories.append("health")
    if data_type == "2" and device_state == "2":
        categories.append("alarm")
    if not categories:
        categories.append("heartbeat")
    return categories


def _insert_typed_event(conn, table_name: str, imei: str, data: dict, sign_time, raw_data: str):
    if table_name not in EVENT_INSERT_TABLES:
        raise ValueError(f"Unsupported IoT event table: {table_name}")

    signature = data.get("signature") or None
    result = conn.execute(f"""
        INSERT INTO {table_name} (imei, event_name, data_type, device_state,
            sign_time, signature, nonce, raw_data)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT DO NOTHING
        RETURNING id
    """, (
        imei,
        data.get("eventName"),
        data.get("dataType"),
        data.get("deviceState"),
        sign_time,
        signature,
        data.get("nonce"),
        raw_data,
    ))
    row = result.fetchone()
    return row[0] if row else None


def _insert_typed_items(
    conn,
    category: str,
    typed_event_id: int,
    imei: str,
    items: list[dict],
    sign_time,
    sync_all_latest_metrics: bool = False,
) -> None:
    if category == "health":
        for item in items:
            attr_name = _normalize_text(item.get("attrName"))
            if not attr_name:
                continue
            numeric_value, prop_value, attr_value_text = _health_item_value_parts(item.get("value"))
            if numeric_value is not None or prop_value is not None:
                conn.execute("""
                    INSERT INTO iot_health_event_items
                        (event_id, imei, attr_name, attr_value, prop_value, sign_time)
                    VALUES (%s, %s, %s, %s, %s, %s)
                """, (typed_event_id, imei, attr_name, numeric_value, prop_value, sign_time))
            if attr_name in HEALTH_METRIC_ATTR_NAMES or sync_all_latest_metrics:
                _upsert_latest_metric(conn, imei, attr_name, numeric_value, attr_value_text, sign_time)
        return

    table_name = "iot_alarm_event_items" if category == "alarm" else "iot_heartbeat_event_items"
    for item in items:
        conn.execute(f"""
            INSERT INTO {table_name} (event_id, imei, attr_name, attr_value, sign_time)
            VALUES (%s, %s, %s, %s, %s)
        """, (typed_event_id, imei, item.get("attrName"), item.get("value"), sign_time))


def _upsert_latest_metric(
    conn,
    imei: str,
    attr_name: str,
    attr_value: float | None,
    attr_value_text: str | None,
    sign_time,
) -> None:
    conn.execute("""
        INSERT INTO iot_device_latest_metrics
            (imei, attr_name, attr_value, attr_value_text, sign_time, updated_at)
        VALUES (%s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
        ON CONFLICT (imei, attr_name) DO UPDATE SET
            attr_value = EXCLUDED.attr_value,
            attr_value_text = EXCLUDED.attr_value_text,
            sign_time = EXCLUDED.sign_time,
            updated_at = CURRENT_TIMESTAMP
        WHERE iot_device_latest_metrics.sign_time IS NULL
           OR (
               EXCLUDED.sign_time IS NOT NULL
               AND EXCLUDED.sign_time >= iot_device_latest_metrics.sign_time
           )
    """, (imei, attr_name, attr_value, attr_value_text, sign_time))


def _flatten_rows(rows: list[tuple]) -> list:
    params = []
    for row in rows:
        params.extend(row)
    return params


def _values_clause(row_count: int, column_count: int) -> str:
    row_placeholder = "(" + ", ".join(["%s"] * column_count) + ")"
    return ", ".join([row_placeholder] * row_count)


def _execute_multirow_insert(conn, table_name: str, columns: tuple[str, ...], rows: list[tuple]) -> None:
    if not rows:
        return
    if table_name not in ITEM_INSERT_TABLES:
        raise ValueError(f"Unsupported IoT item table: {table_name}")

    conn.execute(
        f"""
        INSERT INTO {table_name} ({", ".join(columns)})
        VALUES {_values_clause(len(rows), len(columns))}
        """,
        _flatten_rows(rows),
    )


def _dedupe_device_param_rows(rows: list[tuple[str, str, str, str, str]]) -> list[tuple[str, str, str, str, str]]:
    latest_by_key: dict[tuple[str, str, str], tuple[str, str, str, str, str]] = {}
    for row in rows:
        latest_by_key[(row[0], row[1], row[2])] = row
    return list(latest_by_key.values())


def _upsert_device_params_batch(conn, rows: list[tuple[str, str, str, str, str]]) -> int:
    rows = _dedupe_device_param_rows(rows)
    if not rows:
        return 0

    result = conn.execute(
        f"""
        INSERT INTO iot_device_params
            (imei, param_code, field_name, param_value, create_by)
        VALUES {_values_clause(len(rows), 5)}
        ON CONFLICT (imei, param_code, field_name) DO UPDATE SET
            param_value = EXCLUDED.param_value,
            create_by = EXCLUDED.create_by,
            updated_at = CURRENT_TIMESTAMP
        """,
        _flatten_rows(rows),
    )
    return result.rowcount if result.rowcount is not None else len(rows)


def _prepare_batch_events(conn, batch: list[dict]) -> list[dict]:
    prepared = []
    for batch_ord, data in enumerate(batch):
        imei = data.get("imei")
        if not imei:
            logger.warning("Skip IoT event without imei")
            continue

        current_snapshot = get_bound_device_snapshot(conn, imei)
        if current_snapshot is None:
            logger.info(f"Skip IoT event for unbound or unknown device: imei={imei}")
            continue

        _sync_device_basics_if_changed(conn, imei, data, current_snapshot)
        sign_time = _parse_datetime(data.get("signTime"))
        raw_data = json.dumps(data, ensure_ascii=False)
        perf = _extract_perf(data)
        device_param_rows = _build_reported_device_param_rows(imei, data, current_snapshot)
        prepared.append({
            "batch_ord": batch_ord,
            "data": data,
            "imei": imei,
            "event_name": data.get("eventName"),
            "data_type": data.get("dataType"),
            "device_state": data.get("deviceState"),
            "sign_time": sign_time,
            "typed_signature": data.get("signature") or None,
            "nonce": data.get("nonce"),
            "raw_data": raw_data,
            "items": data.get("items", []) or [],
            "categories": _event_categories(data, current_snapshot),
            "sync_all_latest_metrics": _is_sm_c03_sleep_radar_health_event(data, current_snapshot),
            "device_param_rows": device_param_rows,
            "perf": perf,
        })
    return prepared


def _insert_event_rows_batch(conn, table_name: str, events: list[dict], signature_key: str) -> dict[int, int]:
    if not events:
        return {}
    if table_name not in EVENT_INSERT_TABLES:
        raise ValueError(f"Unsupported IoT event table: {table_name}")

    rows = [
        (
            event["batch_ord"],
            event["imei"],
            event["event_name"],
            event["data_type"],
            event["device_state"],
            event["sign_time"],
            event[signature_key],
            event["nonce"],
            event["raw_data"],
        )
        for event in events
    ]
    result = conn.execute(
        f"""
        WITH raw_payload (
            batch_ord, imei, event_name, data_type, device_state,
            sign_time, signature, nonce, raw_data
        ) AS (
            VALUES {_values_clause(len(rows), 9)}
        ),
        payload AS (
            SELECT
                batch_ord::integer AS batch_ord,
                imei::varchar(32) AS imei,
                event_name::varchar(64) AS event_name,
                data_type::smallint AS data_type,
                device_state::smallint AS device_state,
                sign_time::timestamp AS sign_time,
                signature::varchar(64) AS signature,
                nonce::varchar(32) AS nonce,
                raw_data::text AS raw_data
            FROM raw_payload
        ),
        inserted AS (
            INSERT INTO {table_name} (
                imei, event_name, data_type, device_state,
                sign_time, signature, nonce, raw_data
            )
            SELECT
                imei, event_name, data_type, device_state,
                sign_time, signature, nonce, raw_data
            FROM payload
            ON CONFLICT DO NOTHING
            RETURNING id, imei, event_name, data_type, device_state, sign_time, signature, nonce, raw_data
        ),
        payload_ranked AS (
            SELECT
                *,
                row_number() OVER (
                    PARTITION BY imei, event_name, data_type, device_state, sign_time, signature, nonce, raw_data
                    ORDER BY batch_ord
                ) AS rn
            FROM payload
        ),
        inserted_ranked AS (
            SELECT
                *,
                row_number() OVER (
                    PARTITION BY imei, event_name, data_type, device_state, sign_time, signature, nonce, raw_data
                    ORDER BY id
                ) AS rn
            FROM inserted
        )
        SELECT p.batch_ord, i.id
        FROM payload_ranked p
        JOIN inserted_ranked i
          ON p.imei IS NOT DISTINCT FROM i.imei
         AND p.event_name IS NOT DISTINCT FROM i.event_name
         AND p.data_type IS NOT DISTINCT FROM i.data_type
         AND p.device_state IS NOT DISTINCT FROM i.device_state
         AND p.sign_time IS NOT DISTINCT FROM i.sign_time
         AND p.signature IS NOT DISTINCT FROM i.signature
         AND p.nonce IS NOT DISTINCT FROM i.nonce
         AND p.raw_data IS NOT DISTINCT FROM i.raw_data
         AND p.rn = i.rn
        """,
        _flatten_rows(rows),
    )
    return {batch_ord: event_id for batch_ord, event_id in result.fetchall()}


def _dedupe_latest_metric_rows(rows: list[tuple]) -> list[tuple]:
    latest_by_key: dict[tuple[str, str], tuple] = {}
    for row in rows:
        key = (row[0], row[1])
        current = latest_by_key.get(key)
        if current is None:
            latest_by_key[key] = row
            continue

        current_time = current[4]
        next_time = row[4]
        if current_time is None:
            latest_by_key[key] = row
        elif next_time is not None and next_time >= current_time:
            latest_by_key[key] = row
    return list(latest_by_key.values())


def _upsert_latest_metrics_batch(conn, rows: list[tuple]) -> None:
    rows = _dedupe_latest_metric_rows(rows)
    if not rows:
        return

    values_clause = ", ".join(["(%s, %s, %s, %s, %s, CURRENT_TIMESTAMP)"] * len(rows))
    conn.execute(
        f"""
        INSERT INTO iot_device_latest_metrics
            (imei, attr_name, attr_value, attr_value_text, sign_time, updated_at)
        VALUES {values_clause}
        ON CONFLICT (imei, attr_name) DO UPDATE SET
            attr_value = EXCLUDED.attr_value,
            attr_value_text = EXCLUDED.attr_value_text,
            sign_time = EXCLUDED.sign_time,
            updated_at = CURRENT_TIMESTAMP
        WHERE iot_device_latest_metrics.sign_time IS NULL
           OR (
               EXCLUDED.sign_time IS NOT NULL
               AND EXCLUDED.sign_time >= iot_device_latest_metrics.sign_time
           )
        """,
        _flatten_rows(rows),
    )


def _insert_typed_items_batch(
    conn,
    category: str,
    prepared_by_ord: dict[int, dict],
    event_ids: dict[int, int],
) -> None:
    rows = []
    latest_metric_rows = []

    for batch_ord, event_id in event_ids.items():
        event = prepared_by_ord[batch_ord]
        if category == "health":
            for item in event["items"]:
                attr_name = _normalize_text(item.get("attrName"))
                if not attr_name:
                    continue
                numeric_value, prop_value, attr_value_text = _health_item_value_parts(item.get("value"))
                if numeric_value is not None or prop_value is not None:
                    rows.append((
                        event_id,
                        event["imei"],
                        attr_name,
                        numeric_value,
                        prop_value,
                        event["sign_time"],
                    ))
                if attr_name in HEALTH_METRIC_ATTR_NAMES or event.get("sync_all_latest_metrics"):
                    latest_metric_rows.append((
                        event["imei"],
                        attr_name,
                        numeric_value,
                        attr_value_text,
                        event["sign_time"],
                    ))
            continue

        for item in event["items"]:
            rows.append((
                event_id,
                event["imei"],
                item.get("attrName"),
                item.get("value"),
                event["sign_time"],
            ))

    if category == "health":
        table_name = "iot_health_event_items"
    elif category == "alarm":
        table_name = "iot_alarm_event_items"
    else:
        table_name = "iot_heartbeat_event_items"

    _execute_multirow_insert(
        conn,
        table_name,
        (
            ("event_id", "imei", "attr_name", "attr_value", "prop_value", "sign_time")
            if category == "health"
            else ("event_id", "imei", "attr_name", "attr_value", "sign_time")
        ),
        rows,
    )
    if category == "health":
        _upsert_latest_metrics_batch(conn, latest_metric_rows)


def _record_ingest_performance_batch(
    conn,
    prepared: list[dict],
    inserted_event_ords: set[int],
) -> None:
    rows = []
    for event in prepared:
        if event["batch_ord"] not in inserted_event_ords:
            continue
        perf = event.get("perf") or {}
        if not perf:
            continue

        signature = event.get("typed_signature") or None
        rows.append((
            _normalize_text(perf.get("run_id")),
            _normalize_text(perf.get("trace_id")),
            _parse_int(perf.get("seq")),
            event["imei"],
            event["event_name"],
            ",".join(event["categories"]),
            _normalize_text(signature),
            _parse_float(perf.get("client_send_ms")),
            _parse_float(perf.get("api_received_ms")),
            _parse_float(perf.get("file_write_ms")),
            _parse_float(perf.get("file_read_ms")),
            _normalize_text(perf.get("file_path")),
            _parse_int(perf.get("file_offset_bytes")),
        ))

    if not rows:
        return

    conn.execute(
        f"""
        WITH raw_payload (
            run_id, trace_id, seq, imei, event_name, event_kind, signature,
            client_send_ms, api_received_ms, file_write_ms, file_read_ms,
            file_path, file_offset_bytes
        ) AS (
            VALUES {_values_clause(len(rows), 13)}
        ),
        payload AS (
            SELECT
                run_id::varchar(80) AS run_id,
                trace_id::varchar(128) AS trace_id,
                seq::bigint AS seq,
                imei::varchar(32) AS imei,
                event_name::varchar(64) AS event_name,
                event_kind::varchar(64) AS event_kind,
                signature::varchar(64) AS signature,
                client_send_ms::double precision AS client_send_ms,
                api_received_ms::double precision AS api_received_ms,
                file_write_ms::double precision AS file_write_ms,
                file_read_ms::double precision AS file_read_ms,
                file_path::text AS file_path,
                file_offset_bytes::bigint AS file_offset_bytes
            FROM raw_payload
        )
        INSERT INTO iot_ingest_performance (
            run_id, trace_id, seq, imei, event_name, event_kind, signature,
            client_send_ms, api_received_ms, file_write_ms, file_read_ms,
            db_write_ms, file_path, file_offset_bytes, updated_at
        )
        SELECT
            run_id, trace_id, seq, imei, event_name, event_kind, signature,
            client_send_ms, api_received_ms, file_write_ms, file_read_ms,
            EXTRACT(EPOCH FROM clock_timestamp()) * 1000,
            file_path, file_offset_bytes, CURRENT_TIMESTAMP
        FROM payload
        ON CONFLICT (signature) WHERE signature IS NOT NULL DO UPDATE SET
            run_id = COALESCE(EXCLUDED.run_id, iot_ingest_performance.run_id),
            trace_id = COALESCE(EXCLUDED.trace_id, iot_ingest_performance.trace_id),
            seq = COALESCE(EXCLUDED.seq, iot_ingest_performance.seq),
            imei = COALESCE(EXCLUDED.imei, iot_ingest_performance.imei),
            event_name = COALESCE(EXCLUDED.event_name, iot_ingest_performance.event_name),
            event_kind = COALESCE(EXCLUDED.event_kind, iot_ingest_performance.event_kind),
            client_send_ms = COALESCE(EXCLUDED.client_send_ms, iot_ingest_performance.client_send_ms),
            api_received_ms = COALESCE(EXCLUDED.api_received_ms, iot_ingest_performance.api_received_ms),
            file_write_ms = COALESCE(EXCLUDED.file_write_ms, iot_ingest_performance.file_write_ms),
            file_read_ms = COALESCE(EXCLUDED.file_read_ms, iot_ingest_performance.file_read_ms),
            db_write_ms = EXCLUDED.db_write_ms,
            file_path = COALESCE(EXCLUDED.file_path, iot_ingest_performance.file_path),
            file_offset_bytes = COALESCE(EXCLUDED.file_offset_bytes, iot_ingest_performance.file_offset_bytes),
            updated_at = CURRENT_TIMESTAMP
        """,
        _flatten_rows(rows),
    )


def process_events_batch(conn, batch: list[dict]) -> int:
    """
    批量处理设备事件推送，用于文件监听落库。

    批内事件表、属性表、最新指标表和设备参数表使用多行 INSERT/UPSERT，避免逐条 SQL。
    返回至少有一个分类事件成功插入的事件数量。
    """
    prepared = _prepare_batch_events(conn, batch)
    if not prepared:
        return 0

    prepared_by_ord = {event["batch_ord"]: event for event in prepared}
    inserted_event_ords: set[int] = set()

    event_tables = {
        "health": "iot_health_events",
        "alarm": "iot_alarm_events",
        "heartbeat": "iot_heartbeat_events",
    }
    for category, table_name in event_tables.items():
        category_events = [event for event in prepared if category in event["categories"]]
        typed_event_ids = _insert_event_rows_batch(
            conn,
            table_name,
            category_events,
            "typed_signature",
        )
        inserted_event_ords.update(typed_event_ids.keys())
        _insert_typed_items_batch(conn, category, prepared_by_ord, typed_event_ids)

    device_param_rows = [
        row
        for event in prepared
        for row in event.get("device_param_rows", [])
    ]
    _upsert_device_params_batch(conn, device_param_rows)

    _record_ingest_performance_batch(conn, prepared, inserted_event_ords)

    return len(inserted_event_ords)


def process_event(conn, data: dict):
    """
    统一处理设备事件推送，写入分类事件表和相关明细表。
    由 router.py（HTTP 实时接收）和 file_monitor.py（文件监听）共同调用。

    返回 True（新表事件或参数表有补写）或 None（未知设备、全量重复跳过）。

    写入顺序：
    1. 绑定设备过滤，未绑定设备直接跳过
    2. iot_devices / iot_device_contacts - 缓存对比，有变化才更新
    3. iot_health_events / iot_alarm_events / iot_heartbeat_events - 分类事件表
    4. iot_health_event_items / iot_alarm_event_items / iot_heartbeat_event_items - 分类属性表
    5. iot_device_latest_metrics - 健康指标最新值
    6. iot_device_params - SM-C03 睡眠雷达、RT-C03AI 跌倒雷达参数上报同步
    """
    imei = data.get("imei")

    if not imei:
        logger.warning("Skip IoT event without imei")
        return None

    current_snapshot = get_bound_device_snapshot(conn, imei)
    if current_snapshot is None:
        logger.info(f"Skip IoT event for unbound or unknown device: imei={imei}")
        return None

    _sync_device_basics_if_changed(conn, imei, data, current_snapshot)
    sign_time = _parse_datetime(data.get("signTime"))
    raw_data = json.dumps(data, ensure_ascii=False)
    device_param_rows = _build_reported_device_param_rows(imei, data, current_snapshot)
    items = data.get("items", []) or []

    event_tables = {
        "health": "iot_health_events",
        "alarm": "iot_alarm_events",
        "heartbeat": "iot_heartbeat_events",
    }
    typed_inserted = False
    categories = _event_categories(data, current_snapshot)
    for category in categories:
        typed_event_id = _insert_typed_event(conn, event_tables[category], imei, data, sign_time, raw_data)
        if typed_event_id is not None:
            _insert_typed_items(
                conn,
                category,
                typed_event_id,
                imei,
                items,
                sign_time,
                sync_all_latest_metrics=_is_sm_c03_sleep_radar_health_event(data, current_snapshot),
            )
            typed_inserted = True

    if typed_inserted:
        _record_ingest_performance_batch(
            conn,
            [{
                "batch_ord": 0,
                "imei": imei,
                "event_name": data.get("eventName"),
                "categories": categories,
                "typed_signature": data.get("signature") or None,
                "perf": _extract_perf(data),
            }],
            {0},
        )

    synced_param_count = _upsert_device_params_batch(conn, device_param_rows)

    if typed_inserted:
        return True
    if synced_param_count:
        return True
    return None
