from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, DateTime, Text, JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime
from db_encryption import EncryptedString
import pytz

Base = declarative_base()

def get_beijing_time():
    return datetime.now(pytz.timezone('Asia/Shanghai')).replace(tzinfo=None)

class SystemConfig(Base):
    __tablename__ = "system_configs"
    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(50), unique=True, index=True)
    value = Column(String(200))
    description = Column(String(200))
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time)

class AuditLog(Base):
    __tablename__ = "audit_logs"
    id = Column(Integer, primary_key=True, index=True)
    admin_id = Column(Integer, ForeignKey("users.id"), index=True)
    actor_user_id = Column(Integer, ForeignKey("users.id"), index=True, nullable=True)
    actor_type = Column(String(20), nullable=True)
    actor_name = Column(String(100), nullable=True)
    actor_phone_masked = Column(String(20), nullable=True)
    terminal = Column(String(20), nullable=True, index=True)
    module = Column(String(50), nullable=True, index=True)
    action = Column(String(50))
    result = Column(String(20), nullable=True, index=True)
    target_type = Column(String(50), nullable=True, index=True)
    target_id = Column(String(50), nullable=True)
    details = Column(String(500), nullable=True)
    ip_address = Column(String(64), nullable=True)
    user_agent = Column(String(300), nullable=True)
    request_id = Column(String(64), nullable=True, index=True)
    metadata_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=get_beijing_time)
    
    admin = relationship("User", foreign_keys=[admin_id])
    actor_user = relationship("User", foreign_keys=[actor_user_id])

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    phone = Column(EncryptedString(), nullable=False)
    phone_hash = Column(String(64), unique=True, index=True, nullable=True)
    hashed_password = Column(String, nullable=True)
    display_name = Column(String(100), nullable=True)
    avatar_key = Column(String(50), nullable=True)
    is_admin = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    deactivated_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=get_beijing_time)
    
    profiles = relationship("PatientProfile", back_populates="user", cascade="all, delete-orphan")
    chat_sessions = relationship("ChatSession", back_populates="user", cascade="all, delete-orphan")
    uploaded_files = relationship("ChatUploadedFile", back_populates="user", cascade="all, delete-orphan")

class PatientProfile(Base):
    __tablename__ = "patient_profiles"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(EncryptedString(), nullable=False)
    relation = Column(String(20), nullable=False) # e.g., self, parent, child
    gender = Column(String(10), nullable=False)
    age = Column(Integer, nullable=False)
    
    # Encrypted fields
    medical_history = Column(Text, nullable=True) 
    allergies = Column(Text, nullable=True)
    
    created_at = Column(DateTime, default=get_beijing_time)
    
    user = relationship("User", back_populates="profiles")
    consultations = relationship("ConsultationRecord", back_populates="profile", cascade="all, delete-orphan")

class ConsultationRecord(Base):
    __tablename__ = "consultation_records"
    
    id = Column(Integer, primary_key=True, index=True)
    profile_id = Column(Integer, ForeignKey("patient_profiles.id"))
    
    # Stores the JSON representation of the consultation outcome (medical card)
    symptoms = Column(Text, nullable=True)
    diagnosis = Column(Text, nullable=True)
    advice = Column(Text, nullable=True)
    department = Column(String(100), nullable=True)
    
    chat_history = Column(Text, nullable=True) # JSON string of chat history
    ai_label_meta = Column(JSON().with_variant(JSONB(), "postgresql"), nullable=True)
    
    created_at = Column(DateTime, default=get_beijing_time)
    
    profile = relationship("PatientProfile", back_populates="consultations")

class ChatSession(Base):
    __tablename__ = "chat_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String(120), nullable=False)
    mode = Column(String(20), nullable=False, default="normal")
    messages_json = Column(Text, nullable=False, default="[]")
    is_active = Column(Boolean, default=True)
    token_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=get_beijing_time)
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time)

    user = relationship("User", back_populates="chat_sessions")


class AiFeedback(Base):
    __tablename__ = "ai_feedbacks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    session_id = Column(Integer, ForeignKey("chat_sessions.id"), nullable=True, index=True)
    message_id = Column(String(120), nullable=True, index=True)
    question = Column(Text, nullable=False)
    ai_response = Column(Text, nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=get_beijing_time, index=True)

    user = relationship("User")
    session = relationship("ChatSession")

class ChatUploadedFile(Base):
    __tablename__ = "chat_uploaded_files"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    file_id = Column(String(128), unique=True, nullable=False, index=True)
    file_name = Column(String(255), nullable=False)
    content_type = Column(String(100), nullable=True)
    size = Column(Integer, default=0)
    created_at = Column(DateTime, default=get_beijing_time)

    user = relationship("User", back_populates="uploaded_files")

class HighFreqQuestion(Base):
    __tablename__ = "high_freq_questions"
    
    id = Column(Integer, primary_key=True, index=True)
    question = Column(String(200), nullable=False)
    answer_template = Column(Text, nullable=False)
    category = Column(String(50), nullable=True)
    click_count = Column(Integer, default=0)
    is_top = Column(Boolean, default=False)
    status = Column(String(20), default="draft") # draft, published, disabled
    sort_weight = Column(Integer, default=0)
    created_at = Column(DateTime, default=get_beijing_time)
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time)

class Agreement(Base):
    __tablename__ = "agreements"
    
    id = Column(Integer, primary_key=True, index=True)
    type = Column(String(50), unique=True, index=True, nullable=False) # 'user_agreement', 'privacy_policy'
    title = Column(String(100), nullable=False)
    content = Column(Text, nullable=False) # Rich text
    updated_at = Column(DateTime, default=get_beijing_time, onupdate=get_beijing_time)
