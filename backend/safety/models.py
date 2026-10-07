from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import JSONB
from models import Base, get_beijing_time

class AiSafetyEvent(Base):
    __tablename__ = "ai_safety_events"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)
    terminal = Column(String(20), index=True)
    scene = Column(String(40))
    phase = Column(String(10), index=True)
    session_id = Column(Integer, nullable=True, index=True)
    message_id = Column(String(64), nullable=True)
    intent_code = Column(String(10), index=True)
    category = Column(String(20), index=True)
    risk_level = Column(String(10), index=True)
    action = Column(String(20), index=True)
    matched_rules_json = Column(JSON().with_variant(JSONB(), "postgresql"), nullable=True)
    excerpt = Column(Text, nullable=True)
    reply_text = Column(Text, nullable=True)
    degraded = Column(Boolean, default=False)
    review_status = Column(String(20), default="none", index=True)
    ip_address = Column(String(64), nullable=True)
    request_id = Column(String(64), nullable=True, index=True)
    created_at = Column(DateTime, default=get_beijing_time, index=True)

class AiIntentRule(Base):
    __tablename__ = "ai_intent_rules"
    id = Column(Integer, primary_key=True, index=True)
    scene_name = Column(String(100), nullable=False)
    intent_code = Column(String(10), nullable=False, index=True)
    risk_level = Column(String(10), nullable=False)
    triggers = Column(Text, nullable=False)
    match_mode = Column(String(20), default="keyword")
    reply_template = Column(Text, nullable=True)
    action = Column(String(20), nullable=False)
    scope = Column(String(20), default="all")
    priority = Column(Integer, default=100)
    status = Column(String(20), default="enabled", index=True)
    hit_count = Column(Integer, default=0)
    remark = Column(String(200), nullable=True)
    created_at = Column(DateTime, default=get_beijing_time)
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time)

class AiSensitiveWord(Base):
    __tablename__ = "ai_sensitive_words"
    id = Column(Integer, primary_key=True, index=True)
    category = Column(String(20), nullable=False, index=True)
    content = Column(Text, nullable=False)
    match_mode = Column(String(20), default="contains")
    action = Column(String(20), nullable=False)
    reply_template = Column(Text, nullable=True)
    apply_phase = Column(String(20), default="both")
    scope = Column(String(20), default="all")
    risk_level = Column(String(10), nullable=False)
    whitelist_context = Column(Text, nullable=True)
    priority = Column(Integer, default=100)
    status = Column(String(20), default="enabled", index=True)
    hit_count = Column(Integer, default=0)
    source_version = Column(String(30), nullable=True)
    created_at = Column(DateTime, default=get_beijing_time)
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time)

class AiSafetyTestCase(Base):
    __tablename__ = "ai_safety_test_cases"
    id = Column(Integer, primary_key=True, index=True)
    case_name = Column(String(100), nullable=False)
    input_text = Column(Text, nullable=False)
    expected_path = Column(String(20), nullable=False)
    expected_keywords = Column(String(200), nullable=True)
    last_result = Column(String(20), nullable=True)
    last_run_at = Column(DateTime, nullable=True)
    status = Column(String(20), default="enabled", index=True)
    created_at = Column(DateTime, default=get_beijing_time)
