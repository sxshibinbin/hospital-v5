import re
import unicodedata

_WORDS = [
    ("S3", "dosage", r"(?:\u5242\u91cf|\u6bcf\u65e5|\u6bcf\u5929|\u4e00\u6b21).{0,12}(?:mg|\u6beb\u514b|\u51e0\u7247|\u51e2)", "block", "critical"),
    ("S5", "medication-change", r"(?:\u505c\u836f|\u6362\u836f|\u52a0\u91cf|\u51cf\u91cf|\u81ea\u884c\u8c03\u6574)", "block", "critical"),
    ("S8", "contact-or-ad", r"(?:\u52a0\u6211\u5fae\u4fe1|\u8054\u7cfb\u65b9\u5f0f|\u79c1\u804a|\u5916\u94fe|\u5e7f\u544a)", "block", "high"),
    ("S9", "phone", r"(?<!\d)1[3-9]\d{9}(?!\d)", "block", "high"),
    ("S6", "exaggerated-cure", r"(?:\u6839\u6cbb|\u5305\u6cbb|\u767e\u5206\u767e\u6709\u6548|\u65e0\u526f\u4f5c\u7528)", "rewrite_guide", "medium"),
]
_DYNAMIC_WORDS = []

def configure_dynamic_words(rows):
    global _DYNAMIC_WORDS
    _DYNAMIC_WORDS = [
        (row.category, str(row.category), row.content, row.action, row.risk_level)
        for row in rows
        if getattr(row, "status", "enabled") == "enabled" and getattr(row, "content", None)
    ]

def normalize_text(text: str) -> str:
    value = unicodedata.normalize("NFKC", str(text or "")).lower()
    value = re.sub(r"[\u200b-\u200f\u2060\ufeff]", "", value)
    return re.sub(r"[\s\-_/\\\u00b7\u2022]+", "", value)


def _is_negated_medication_change(text: str, match: re.Match[str]) -> bool:
    """Return True when a medication-change phrase is being prohibited."""
    prefix = text[max(0, match.start() - 18):match.start()]
    return bool(re.search(r"(?:不要|请勿|切勿|禁止|不可|不能|不应|不宜|不建议|避免|不得|严禁)", prefix))

def match_words(text: str) -> list[dict]:
    normalized = normalize_text(text)
    # Safety explanations commonly contain warnings such as
    # "不要自行调整用药". Do not treat those warnings as instructions to
    # change medication, while keeping positive suggestions blocked.
    normalized = re.sub(
        r"(?:不建议|不要|请勿|切勿|禁止|不可|不能)自行(?:停药|服用|调整|加量|减量|换药)(?:[或和、,，](?:停药|服用|调整|加量|减量|换药))*",
        "",
        normalized,
    )
    hits = []
    for category, name, pattern, action, risk in [*_WORDS, *_DYNAMIC_WORDS]:
        runtime_pattern = pattern.encode("ascii").decode("unicode_escape") if "\\u" in pattern else pattern
        matches = list(re.finditer(runtime_pattern, normalized, re.I))
        if category == "S5":
            matches = [match for match in matches if not _is_negated_medication_change(normalized, match)]
        if matches:
            hits.append({"category": category, "name": name, "pattern": pattern, "action": action, "risk_level": risk})
    return hits
