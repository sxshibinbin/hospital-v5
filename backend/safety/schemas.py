from dataclasses import dataclass, field
from typing import Any

@dataclass
class SafetyDecision:
    intent_code: str = "I12"
    risk_level: str = "none"
    action: str = "model_fallback"
    reply_template: str | None = None
    matched_rules: list[dict[str, Any]] = field(default_factory=list)
    phase: str = "input"
    decision_id: str = ""
    degraded: bool = False

    @property
    def blocked(self) -> bool:
        return self.action in {"fixed_reply", "block", "refuse_guide", "emergency_guide", "rewrite_guide"}
