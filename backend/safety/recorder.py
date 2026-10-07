from sqlalchemy.ext.asyncio import AsyncSession
from .models import AiSafetyEvent
from .schemas import SafetyDecision
from .constants import RECORD_EXCERPT_LEN

async def record_event(db: AsyncSession, *, user_id: int | None, terminal: str, scene: str, text: str, decision: SafetyDecision, reply_text: str | None = None, session_id: int | None = None, request_id: str | None = None):
    if not decision.matched_rules and decision.risk_level == "none":
        return
    db.add(AiSafetyEvent(user_id=user_id, terminal=terminal, scene=scene, phase=decision.phase, session_id=session_id, intent_code=decision.intent_code, category=(decision.matched_rules[0].get("category") if decision.matched_rules else None), risk_level=decision.risk_level, action=decision.action, matched_rules_json=decision.matched_rules, excerpt=str(text or "")[:RECORD_EXCERPT_LEN], reply_text=reply_text, degraded=decision.degraded, review_status="pending" if decision.risk_level == "critical" else "none", request_id=request_id))
    await db.commit()
