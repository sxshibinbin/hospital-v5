from fastapi import HTTPException

from models import User


def current_iot_user_id(current_user: User) -> int:
    return int(current_user.id)


def current_operator_name(current_user: User) -> str:
    return (
        (current_user.display_name or "").strip()
        or current_user.phone
        or str(current_user.id)
    )[:32]


def ensure_device_access(conn, user_id: int, device_imei: str) -> None:
    row = conn.execute(
        """
        SELECT 1
        FROM iot_user_devices
        WHERE user_id = %s
          AND device_imei = %s
          AND status = 1
        LIMIT 1
        """,
        (user_id, device_imei),
    ).fetchone()
    if row is None:
        raise PermissionError("设备不存在或无访问权限")


def ensure_event_access(conn, user_id: int, event_id: int, event_table: str) -> str:
    if event_table not in {"iot_heartbeat_events", "iot_alarm_events", "iot_health_events"}:
        raise HTTPException(status_code=500, detail="Unsupported event table")

    row = conn.execute(
        f"""
        SELECT e.imei
        FROM {event_table} e
        INNER JOIN iot_user_devices ud
          ON ud.device_imei = e.imei
         AND ud.user_id = %s
         AND ud.status = 1
        WHERE e.id = %s
        LIMIT 1
        """,
        (user_id, event_id),
    ).fetchone()
    if row is None:
        raise PermissionError("事件不存在或无访问权限")
    return row[0]
