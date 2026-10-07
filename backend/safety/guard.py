import uuid
from .constants import REPLIES, INPUT_GUARD_ENABLED, OUTPUT_GUARD_ENABLED
from .intent import classify_intent
from .schemas import SafetyDecision
from .wordbank import match_words

def check_input(text: str, history: list[dict] | None = None, scope: str = "all") -> SafetyDecision:
    decision = SafetyDecision(decision_id=uuid.uuid4().hex, phase="input")
    if not INPUT_GUARD_ENABLED:
        return decision
    hits = match_words(text)
    decision.matched_rules = hits
    if hits:
        hit = sorted(hits, key=lambda item: {"critical": 4, "high": 3, "medium": 2, "low": 1}.get(item["risk_level"], 0), reverse=True)[0]
        decision.intent_code = {"S3": "I4", "S5": "I6"}.get(hit["category"], "I12")
        decision.action = hit["action"]
        decision.risk_level = hit["risk_level"]
        decision.reply_template = REPLIES["I4"] if hit["category"] == "S3" else REPLIES["default"]
        return decision
    intent = classify_intent(text)
    if intent:
        code, risk, action = intent
        decision.intent_code, decision.risk_level, decision.action = code, risk, action
        decision.reply_template = REPLIES.get(code, REPLIES["default"])
    return decision

def check_output(text: str, scope: str = "all") -> SafetyDecision:
    decision = SafetyDecision(decision_id=uuid.uuid4().hex, phase="output")
    if not OUTPUT_GUARD_ENABLED:
        return decision
    hits = match_words(text)
    decision.matched_rules = hits
    if hits:
        hit = max(hits, key=lambda item: {"critical": 4, "high": 3, "medium": 2, "low": 1}.get(item["risk_level"], 0))
        decision.action = hit["action"]
        decision.risk_level = hit["risk_level"]
        decision.reply_template = REPLIES["I4"] if hit["category"] == "S3" else REPLIES["default"]
    return decision
