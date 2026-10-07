import re

_RULES = [
    ("I11", "critical", "emergency_guide", r"\u81ea\u6740|\u8f7b\u751f|\u4e0d\u60f3\u6d3b|\u5bfb\u6b7b|\u8fc7\u91cf\u670d\u836f|\u5272\u8155"),
    ("I4", "critical", "refuse_guide", r"\u5242\u91cf|\u6bcf\u5929\u5403\u51e0\u7247|\u4e00\u6b21\u5403\u51e0\u7247|\u591a\u5c11\u6beb\u514b|\u7528\u91cf"),
    ("I6", "critical", "refuse_guide", r"\u505c\u836f|\u6362\u836f|\u52a0\u91cf|\u51cf\u91cf|\u81ea\u884c\u8c03\u6574"),
    ("I7", "critical", "refuse_guide", r"\u5f00\u5904\u65b9|\u5f00\u4e2a\u836f\u65b9|\u5904\u65b9\u836f"),
    ("I1", "high", "refuse_guide", r"\u5e2e\u6211\u8bca\u65ad|\u786e\u8bca|\u8bca\u65ad\u4e00\u4e0b"),
    ("I2", "high", "refuse_guide", r"\u8fd9\u4e2a\u75c7\u72b6.*(?:\u4ec0\u4e48\u75c5|\u662f\u75c5\u5417)|\u6211\u5f97\u4e86\u4ec0\u4e48\u75c5"),
    ("I3", "high", "refuse_guide", r"\u5403\u4ec0\u4e48\u836f|\u63a8\u8350.*\u836f|\u7528\u4ec0\u4e48\u836f"),
    ("I5", "high", "refuse_guide", r"\u4f1a\u4e0d\u4f1a\u6b7b|\u751f\u547d\u5371\u9669|\u4e25\u91cd\u5417"),
    ("I8", "medium", "rewrite_guide", r"\u504f\u65b9|\u66ff\u4ee3\u6cbb\u7597"),
]
_DYNAMIC_RULES = []

def configure_dynamic_intents(rows):
    global _DYNAMIC_RULES
    _DYNAMIC_RULES = [
        (row.intent_code, row.risk_level, row.action, row.triggers)
        for row in rows
        if getattr(row, "status", "enabled") == "enabled" and getattr(row, "triggers", None)
    ]

def classify_intent(text: str) -> tuple[str, str, str] | None:
    value = str(text or "").lower()
    for code, risk, action, pattern in [*_DYNAMIC_RULES, *_RULES]:
        runtime_pattern = pattern.encode("ascii").decode("unicode_escape") if "\\u" in pattern else pattern
        if re.search(runtime_pattern, value, re.I):
            return code, risk, action
    return None
