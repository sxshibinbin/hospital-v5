"""Health-monitoring report intent recognition and fact aggregation."""

from __future__ import annotations

import asyncio
import re
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from statistics import median
from typing import Dict, Iterable, List, Optional, Sequence

METRICS = {
    "heart_rate": {
        "name": "心率",
        "aliases": ("心率",),
        "unit": "次/分",
        "low": 60.0,
        "high": 100.0,
    },
    "spo2": {
        "name": "血氧",
        "aliases": ("血氧", "血氧饱和度"),
        "unit": "%",
        "low": 90.0,
        "high": 100.0,
    },
    "systolic": {
        "name": "收缩压",
        "aliases": ("收缩压",),
        "unit": "mmHg",
        "low": 90.0,
        "high": 140.0,
    },
    "diastolic": {
        "name": "舒张压",
        "aliases": ("舒张压",),
        "unit": "mmHg",
        "low": 60.0,
        "high": 90.0,
    },
    "temperature": {
        "name": "体温",
        "aliases": ("温度", "体温"),
        "unit": "℃",
        "low": 36.0,
        "high": 37.3,
    },
    "respiratory_rate": {
        "name": "呼吸",
        "aliases": ("呼吸", "呼吸次数"),
        "unit": "次/分",
        "low": 12.0,
        "high": 20.0,
    },
}

_OBJECT_WORDS = ("健康", "监测", "检测", "体温", "心率", "血压", "血氧", "呼吸")
_REPORT_WORDS = ("报告", "总结", "汇总", "概况", "健康情况", "生成", "查看")
_ANALYSIS_WORDS = ("异常", "趋势", "波动", "变化", "怎么样", "如何", "情况")
_TIME_WORDS = ("今天", "昨日", "昨天", "前天", "本周", "这周", "上周", "本月", "这个月", "近", "最近", "过去")
_LATEST_WORDS = ("最近一次", "最新一次", "最新", "最近")
_WEEKDAY_NAMES = ("周一", "周二", "周三", "周四", "周五", "周六", "周日")


@dataclass(frozen=True)
class HealthReportRequest:
    start_date: date
    end_date: date
    label: str


@dataclass(frozen=True)
class LatestMetricRequest:
    metric_keys: tuple[str, ...]


def parse_health_report_intent(message: str, today: Optional[date] = None) -> Optional[HealthReportRequest]:
    """Return a report period only for explicit health-report requests.

    The deliberately conservative match keeps ordinary health knowledge Q&A on
    the original chat path.
    """
    text = (message or "").strip()
    if not text or not any(word in text for word in _OBJECT_WORDS):
        return None

    has_report_request = any(word in text for word in _REPORT_WORDS)
    has_timed_analysis = (
        any(word in text for word in _TIME_WORDS)
        and any(word in text for word in _ANALYSIS_WORDS)
    )
    if not (has_report_request or has_timed_analysis):
        return None

    return _parse_period(text, today or datetime.now().date())


def should_handle_health_report(
    message: str,
    *,
    mode: str,
    has_attachments: bool,
    today: Optional[date] = None,
) -> Optional[HealthReportRequest]:
    """Return a report request only for the untouched normal Q&A path.

    Medical consultation and file/image conversations retain their existing
    handlers even if their text happens to mention a health report.
    """
    if mode != "normal" or has_attachments:
        return None
    return parse_health_report_intent(message, today)


def should_handle_latest_metric(
    message: str,
    *,
    mode: str,
    has_attachments: bool,
) -> Optional[LatestMetricRequest]:
    """Recognize an explicit request for the user's latest measured value."""
    if mode != "normal" or has_attachments:
        return None
    text = (message or "").strip()
    if not text or not any(word in text for word in _LATEST_WORDS):
        return None

    keys: List[str] = []
    if "血压" in text:
        keys.extend(["systolic", "diastolic"])
    for key, metric in METRICS.items():
        if key in {"systolic", "diastolic"}:
            continue
        if any(alias in text for alias in metric["aliases"]):
            keys.append(key)
    return LatestMetricRequest(tuple(dict.fromkeys(keys))) if keys else None


def _parse_period(text: str, today: date) -> HealthReportRequest:
    if "前天" in text:
        target = today - timedelta(days=2)
        return HealthReportRequest(target, target, "前天")
    if "昨日" in text or "昨天" in text:
        target = today - timedelta(days=1)
        return HealthReportRequest(target, target, "昨日")
    if "今天" in text or "今日" in text:
        return HealthReportRequest(today, today, "今日")
    if "上周" in text:
        week_end = today - timedelta(days=today.weekday() + 1)
        return HealthReportRequest(week_end - timedelta(days=6), week_end, "上周")
    if "本周" in text or "这周" in text:
        return HealthReportRequest(today - timedelta(days=today.weekday()), today, "本周")
    if "本月" in text or "这个月" in text:
        return HealthReportRequest(today.replace(day=1), today, "本月")

    days_match = re.search(r"(?:近|最近|过去)\s*(\d{1,3})\s*(?:天|日)", text)
    if days_match:
        days = max(1, min(int(days_match.group(1)), 90))
        return HealthReportRequest(today - timedelta(days=days - 1), today, f"近 {days} 天")

    # No time phrase is still an explicit report request: use the documented
    # default of the last seven calendar days.
    return HealthReportRequest(today - timedelta(days=6), today, "近 7 天")


async def build_health_report_facts(user_id: int, report_request: HealthReportRequest) -> str:
    """Fetch only the authenticated user's device data and build trusted facts."""
    return await asyncio.to_thread(_build_health_report_facts, user_id, report_request)


async def build_latest_metric_response(user_id: int, request: LatestMetricRequest) -> str:
    """Return a deterministic latest-measurement reply, never an LLM guess."""
    return await asyncio.to_thread(_build_latest_metric_response, user_id, request)


def _build_latest_metric_response(user_id: int, request: LatestMetricRequest) -> str:
    from iot_subscription.database import get_connection

    aliases = tuple(
        alias
        for key in request.metric_keys
        for alias in METRICS[key]["aliases"]
    )
    placeholders = ",".join(["%s"] * len(aliases))
    query = f"""
        SELECT hi.event_id, hi.attr_name, hi.attr_value, hi.sign_time
        FROM iot_health_event_items hi
        INNER JOIN iot_user_devices ud
          ON ud.device_imei = hi.imei
         AND ud.user_id = %s
         AND ud.status = 1
        WHERE hi.attr_name IN ({placeholders})
          AND hi.attr_value IS NOT NULL
        ORDER BY hi.sign_time DESC NULLS LAST, hi.id DESC
        LIMIT 1
    """
    with get_connection() as conn:
        latest = conn.execute(query, [user_id, *aliases]).fetchone()
        if latest is None:
            return "未查询到您当前已绑定设备的相关监测数据。请确认设备已绑定并成功上报数据后再试。"
        event_id, _attr_name, _value, sign_time = latest
        rows = conn.execute(
            f"""
            SELECT attr_name, attr_value
            FROM iot_health_event_items
            WHERE event_id = %s AND attr_name IN ({placeholders}) AND attr_value IS NOT NULL
            """,
            [event_id, *aliases],
        ).fetchall()

    values = {str(name): float(value) for name, value in rows}
    timestamp = _format_measurement_time(sign_time)
    if set(request.metric_keys) == {"systolic", "diastolic"}:
        systolic = values.get("收缩压")
        diastolic = values.get("舒张压")
        if systolic is None or diastolic is None:
            return f"最近一次血压事件时间：{timestamp}。该事件血压数据不完整，无法提供完整的收缩压/舒张压结果。"
        return (
            f"最近一次血压监测数据：{_format_number(systolic, 0)}/{_format_number(diastolic, 0)} mmHg，"
            f"测量时间：{timestamp}。"
        )

    lines = [f"最近一次监测时间：{timestamp}。"]
    for key in request.metric_keys:
        metric = METRICS[key]
        value = next((values.get(alias) for alias in metric["aliases"] if alias in values), None)
        if value is None:
            lines.append(f"{metric['name']}：该次事件未上报有效数据。")
        else:
            lines.append(f"{metric['name']}：{_format_number(value)}{metric['unit']}。")
    return "\n".join(lines)


def _format_measurement_time(value: object) -> str:
    if not isinstance(value, datetime):
        return "时间未知"
    return f"{value.strftime('%Y-%m-%d %H:%M')}（{_WEEKDAY_NAMES[value.weekday()]}）"


def _build_health_report_facts(user_id: int, report_request: HealthReportRequest) -> str:
    # Keep intent parsing independently testable and load the IoT driver only
    # when a report actually needs database access.
    from iot_subscription.database import get_connection

    start_dt = datetime.combine(report_request.start_date, datetime.min.time())
    end_dt = datetime.combine(report_request.end_date + timedelta(days=1), datetime.min.time())
    previous_end = start_dt
    period_days = (report_request.end_date - report_request.start_date).days + 1
    previous_start = previous_end - timedelta(days=period_days)
    aliases = tuple(alias for metric in METRICS.values() for alias in metric["aliases"])
    placeholders = ",".join(["%s"] * len(aliases))

    query = f"""
        SELECT hi.attr_name, hi.attr_value, hi.sign_time
        FROM iot_health_event_items hi
        INNER JOIN iot_user_devices ud
          ON ud.device_imei = hi.imei
         AND ud.user_id = %s
         AND ud.status = 1
        WHERE hi.sign_time >= %s
          AND hi.sign_time < %s
          AND hi.attr_name IN ({placeholders})
          AND hi.attr_value IS NOT NULL
        ORDER BY hi.sign_time ASC, hi.id ASC
    """
    with get_connection() as conn:
        current_rows = conn.execute(query, [user_id, start_dt, end_dt, *aliases]).fetchall()
        previous_rows = conn.execute(query, [user_id, previous_start, previous_end, *aliases]).fetchall()

    current = _group_metric_rows(current_rows)
    previous = _group_metric_rows(previous_rows)
    period = f"{report_request.start_date.isoformat()} 至 {report_request.end_date.isoformat()}"
    facts = [
        "【健康监测报告事实摘要】",
        f"统计周期：{period}（{report_request.label}）。",
        "数据范围：仅当前登录用户已绑定且有效设备的健康监测数据。",
    ]

    if not current:
        facts.extend([
            "结论：该统计周期内未获取到可用的体温、心率、血压、呼吸或血氧历史数据。",
            "报告要求：说明数据不足；不要猜测设备状态、数值或健康结论。",
        ])
        return "\n".join(facts)

    facts.append(f"可用指标：{'、'.join(METRICS[key]['name'] for key in current)}。")
    for key, values in current.items():
        metric = METRICS[key]
        facts.append(_summarize_metric(metric, values, previous.get(key, [])))

    missing = [metric["name"] for key, metric in METRICS.items() if key not in current]
    if missing:
        facts.append(f"未获取到以下指标的数据：{'、'.join(missing)}。不评价这些指标。")
    facts.append("报告要求：只做健康管理总结，不作疾病诊断，不逐条列出原始检测记录。")
    return "\n".join(facts)


def _group_metric_rows(rows: Iterable[Sequence[object]]) -> Dict[str, List[float]]:
    alias_map = {alias: key for key, metric in METRICS.items() for alias in metric["aliases"]}
    grouped: Dict[str, List[float]] = {}
    for attr_name, value, _sign_time in rows:
        key = alias_map.get(str(attr_name))
        if key is None:
            continue
        try:
            numeric_value = float(value)
        except (TypeError, ValueError):
            continue
        grouped.setdefault(key, []).append(numeric_value)
    return grouped


def _format_number(value: float, digits: int = 1) -> str:
    formatted = f"{value:.{digits}f}"
    # Integer values such as systolic pressure 110 must retain their trailing
    # zero. Only trim insignificant zeroes from a decimal representation.
    return formatted.rstrip("0").rstrip(".") if digits > 0 else formatted


def _summarize_metric(metric: Dict[str, object], values: List[float], previous_values: List[float]) -> str:
    average = sum(values) / len(values)
    abnormal_count = sum(value < metric["low"] or value > metric["high"] for value in values)
    direction = ""
    if previous_values:
        previous_average = sum(previous_values) / len(previous_values)
        delta = average - previous_average
        # Ignore small changes that are unlikely to be meaningful for a summary.
        threshold = max(0.3, abs(previous_average) * 0.05)
        if abs(delta) >= threshold:
            direction = "较上一等长周期上升" if delta > 0 else "较上一等长周期下降"

    unit = str(metric["unit"])
    base = (
        f"{metric['name']}：有效数据 {len(values)} 条，中位值 {_format_number(median(values))}{unit}，"
        f"范围 {_format_number(min(values))}–{_format_number(max(values))}{unit}。"
    )
    if abnormal_count == 0:
        status = "未发现超出当前参考范围的记录"
    elif abnormal_count == 1:
        status = "出现 1 次超出当前参考范围的记录，属于偶发波动"
    elif abnormal_count / len(values) >= 0.2:
        status = f"有 {abnormal_count} 次超出当前参考范围的记录，存在持续异常倾向"
    else:
        status = f"有 {abnormal_count} 次超出当前参考范围的记录，需要关注波动"
    return f"{base}{status}{'，' + direction if direction else ''}。"
