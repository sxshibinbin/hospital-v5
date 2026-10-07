import pytz
from datetime import datetime
import json
import re
from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from models import ConsultationRecord, PatientProfile, User
from database import get_db
from dependencies import get_current_user
from operation_log_service import log_operation_safe
from pydantic import BaseModel
from security import decrypt_data, encrypt_data
from typing import List, Literal, Optional
from ai_label import build_ai_label_meta

router = APIRouter(prefix="/api/consultations", tags=["consultations"])

def get_beijing_time():
    return datetime.now(pytz.timezone('Asia/Shanghai')).replace(tzinfo=None)

DEFAULT_PROFILE_NAME = "本人"
DEFAULT_PROFILE_RELATION = "self"
DEFAULT_PROFILE_GENDER = "未填写"
DEFAULT_PROFILE_AGE = 0
MAX_CONTEXT_RECORDS = 5
MAX_CONTEXT_PROFILES = 3

class ConsultationCreate(BaseModel):
    profile_id: int
    symptoms: Optional[str] = None
    diagnosis: Optional[str] = None
    advice: Optional[str] = None
    department: Optional[str] = None
    chat_history: Optional[str] = None

class ConsultationResponse(ConsultationCreate):
    id: int
    ai_label_meta: Optional[dict] = None

    class Config:
        from_attributes = True


class ConsultationCardData(BaseModel):
    summary: Optional[str] = None
    analysis: Optional[str] = None
    recommended_department: Optional[str] = None
    hospital_suggestion: Optional[str] = None


class ConsultationChatTurn(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class SaveConsultationRequest(BaseModel):
    profile_id: Optional[int] = None
    card_data: ConsultationCardData
    chat_history: List[ConsultationChatTurn] = []


class SavedConsultationResponse(BaseModel):
    id: int
    profile_id: int
    profile_name: str
    relation: str
    summary: Optional[str] = None
    analysis: Optional[str] = None
    recommended_department: Optional[str] = None
    hospital_suggestion: Optional[str] = None
    created_at: datetime
    ai_label_meta: Optional[dict] = None


def normalize_text(value: Optional[str]) -> Optional[str]:
    if not isinstance(value, str):
        return None

    normalized_value = value.strip()
    return normalized_value or None


async def get_default_profile(db: AsyncSession, current_user: User) -> PatientProfile:
    stmt = (
        select(PatientProfile)
        .where(PatientProfile.user_id == current_user.id)
        .order_by(PatientProfile.created_at.asc())
    )
    result = await db.execute(stmt)
    profiles = result.scalars().all()

    if profiles:
        self_profile = next((item for item in profiles if item.relation == DEFAULT_PROFILE_RELATION), None)
        return self_profile or profiles[0]

    profile = PatientProfile(
        user_id=current_user.id,
        name=DEFAULT_PROFILE_NAME,
        relation=DEFAULT_PROFILE_RELATION,
        gender=DEFAULT_PROFILE_GENDER,
        age=DEFAULT_PROFILE_AGE,
        medical_history=None,
        allergies=None,
    )
    db.add(profile)
    await db.flush()
    return profile


async def get_profile_for_consultation(
    db: AsyncSession,
    current_user: User,
    profile_id: Optional[int],
) -> PatientProfile:
    if profile_id is None:
        return await get_default_profile(db, current_user)

    stmt = select(PatientProfile).where(
        PatientProfile.id == profile_id,
        PatientProfile.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    profile = result.scalars().first()

    if profile is None:
        raise HTTPException(status_code=404, detail="未找到对应的咨询人档案")

    return profile


def format_consultation_history_entry(card_data: ConsultationCardData, created_at: datetime) -> str:
    entry_lines = [f"[{created_at.strftime('%Y-%m-%d %H:%M')}] AI 问诊记录"]

    if normalize_text(card_data.summary):
        entry_lines.append(f"患者概览：{card_data.summary.strip()}")
    if normalize_text(card_data.analysis):
        entry_lines.append(f"病情分析：{card_data.analysis.strip()}")
    if normalize_text(card_data.recommended_department):
        entry_lines.append(f"推荐科室：{card_data.recommended_department.strip()}")
    if normalize_text(card_data.hospital_suggestion):
        entry_lines.append(f"就医建议：{card_data.hospital_suggestion.strip()}")

    return "\n".join(entry_lines)


def update_profile_medical_history(profile: PatientProfile, card_data: ConsultationCardData, created_at: datetime) -> None:
    next_entry = format_consultation_history_entry(card_data, created_at)
    existing_history = normalize_text(decrypt_data(profile.medical_history))
    merged_history = "\n\n".join([item for item in [existing_history, next_entry] if item])
    profile.medical_history = encrypt_data(merged_history)


def remove_profile_medical_history_entry(
    profile: PatientProfile,
    record: ConsultationRecord,
) -> None:
    existing_history = normalize_text(decrypt_data(profile.medical_history))
    if not existing_history:
        return

    target_entry = format_consultation_history_entry(
        ConsultationCardData(
            summary=record.symptoms,
            analysis=record.diagnosis,
            recommended_department=record.department,
            hospital_suggestion=record.advice,
        ),
        record.created_at,
    ).strip()
    entries = [
        entry.strip()
        for entry in re.split(r"\r?\n\r?\n", existing_history)
        if entry.strip()
    ]

    remaining_entries: List[str] = []
    removed = False
    for entry in entries:
        if not removed and entry == target_entry:
            removed = True
            continue
        remaining_entries.append(entry)

    merged_history = "\n\n".join(remaining_entries)
    profile.medical_history = encrypt_data(merged_history) if merged_history else None


def serialize_saved_consultation(record: ConsultationRecord, profile: PatientProfile) -> SavedConsultationResponse:
    return SavedConsultationResponse(
        id=record.id,
        profile_id=profile.id,
        profile_name=profile.name,
        relation=profile.relation,
        summary=record.symptoms,
        analysis=record.diagnosis,
        recommended_department=record.department,
        hospital_suggestion=record.advice,
        created_at=record.created_at,
        ai_label_meta=record.ai_label_meta,
    )


async def build_user_case_context(db: AsyncSession, user_id: int) -> Optional[str]:
    profile_stmt = (
        select(PatientProfile)
        .where(PatientProfile.user_id == user_id)
        .order_by(PatientProfile.created_at.asc())
    )
    profile_result = await db.execute(profile_stmt)
    profiles = profile_result.scalars().all()

    consultation_stmt = (
        select(ConsultationRecord, PatientProfile)
        .join(PatientProfile, ConsultationRecord.profile_id == PatientProfile.id)
        .where(PatientProfile.user_id == user_id)
        .order_by(desc(ConsultationRecord.created_at))
        .limit(MAX_CONTEXT_RECORDS)
    )
    consultation_result = await db.execute(consultation_stmt)
    consultations = consultation_result.all()

    if not profiles and not consultations:
        return None

    sections: List[str] = []

    profile_lines: List[str] = []
    for profile in profiles[:MAX_CONTEXT_PROFILES]:
        line_parts = [f"- 档案：{profile.name}（关系：{profile.relation}，性别：{profile.gender}，年龄：{profile.age}）"]
        medical_history = normalize_text(decrypt_data(profile.medical_history))
        allergies = normalize_text(decrypt_data(profile.allergies))
        if medical_history:
            line_parts.append(f"既往病史：{medical_history}")
        if allergies:
            line_parts.append(f"过敏史：{allergies}")
        profile_lines.append("；".join(line_parts))

    if profile_lines:
        sections.append("【用户档案】\n" + "\n".join(profile_lines))

    consultation_lines: List[str] = []
    for consultation, profile in consultations:
        line_parts = [
            f"- {consultation.created_at.strftime('%Y-%m-%d %H:%M')}，{profile.name}",
        ]
        if normalize_text(consultation.symptoms):
            line_parts.append(f"患者概览：{consultation.symptoms}")
        if normalize_text(consultation.diagnosis):
            line_parts.append(f"病情分析：{consultation.diagnosis}")
        if normalize_text(consultation.department):
            line_parts.append(f"推荐科室：{consultation.department}")
        if normalize_text(consultation.advice):
            line_parts.append(f"就医建议：{consultation.advice}")
        consultation_lines.append("；".join(line_parts))

    if consultation_lines:
        sections.append("【最近保存的问诊记录】\n" + "\n".join(consultation_lines))

    return "\n\n".join(sections) if sections else None


async def build_profile_case_context(
    db: AsyncSession,
    user_id: int,
    profile_id: int,
) -> Optional[str]:
    profile_stmt = select(PatientProfile).where(
        PatientProfile.id == profile_id,
        PatientProfile.user_id == user_id,
    )
    profile_result = await db.execute(profile_stmt)
    profile = profile_result.scalars().first()

    if profile is None:
        return None

    consultation_stmt = (
        select(ConsultationRecord)
        .where(ConsultationRecord.profile_id == profile.id)
        .order_by(desc(ConsultationRecord.created_at))
        .limit(MAX_CONTEXT_RECORDS)
    )
    consultation_result = await db.execute(consultation_stmt)
    consultations = consultation_result.scalars().all()

    sections: List[str] = []
    medical_history = normalize_text(decrypt_data(profile.medical_history))
    allergies = normalize_text(decrypt_data(profile.allergies))

    profile_line_parts = [
        f"- 档案：{profile.name}（关系：{profile.relation}，性别：{profile.gender}，年龄：{profile.age}）"
    ]
    if medical_history:
        profile_line_parts.append(f"既往病史：{medical_history}")
    if allergies:
        profile_line_parts.append(f"过敏史：{allergies}")
    sections.append("【当前咨询人档案】\n" + "；".join(profile_line_parts))

    if consultations:
        consultation_lines: List[str] = []
        for consultation in consultations:
            line_parts = [
                f"- {consultation.created_at.strftime('%Y-%m-%d %H:%M')}，{profile.name}",
            ]
            if normalize_text(consultation.symptoms):
                line_parts.append(f"患者概览：{consultation.symptoms}")
            if normalize_text(consultation.diagnosis):
                line_parts.append(f"病情分析：{consultation.diagnosis}")
            if normalize_text(consultation.department):
                line_parts.append(f"推荐科室：{consultation.department}")
            if normalize_text(consultation.advice):
                line_parts.append(f"就医建议：{consultation.advice}")
            consultation_lines.append("；".join(line_parts))
        sections.append("【当前咨询人的最近问诊记录】\n" + "\n".join(consultation_lines))

    return "\n\n".join(sections) if sections else None

@router.post("", response_model=ConsultationResponse)
async def create_consultation(consultation: ConsultationCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    stmt = select(PatientProfile).where(PatientProfile.id == consultation.profile_id, PatientProfile.user_id == current_user.id)
    result = await db.execute(stmt)
    if not result.scalars().first():
        raise HTTPException(status_code=403, detail="Not authorized to use this profile")
        
    db_consultation = ConsultationRecord(
        profile_id=consultation.profile_id,
        symptoms=consultation.symptoms,
        diagnosis=consultation.diagnosis,
        advice=consultation.advice,
        department=consultation.department,
        chat_history=consultation.chat_history,
        ai_label_meta=build_ai_label_meta(),
        created_at=get_beijing_time()
    )
    db.add(db_consultation)
    await db.commit()
    await db.refresh(db_consultation)
    return db_consultation


@router.post("/save-card", response_model=SavedConsultationResponse)
async def save_consultation_card(
    payload: SaveConsultationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    profile = await get_profile_for_consultation(db, current_user, payload.profile_id)
    
    # 检查数据库中是否已存在相同的问诊记录
    # 判断标准：同一个 profile，且关键字段（symptoms, diagnosis）相同，以防重复保存
    existing_stmt = select(ConsultationRecord).where(
        ConsultationRecord.profile_id == profile.id,
        ConsultationRecord.symptoms == normalize_text(payload.card_data.summary),
        ConsultationRecord.diagnosis == normalize_text(payload.card_data.analysis)
    )
    existing_result = await db.execute(existing_stmt)
    if existing_result.scalars().first():
        raise HTTPException(status_code=409, detail="该问诊记录已经保存过，请勿重复保存")

    consultation = ConsultationRecord(
        profile_id=profile.id,
        symptoms=normalize_text(payload.card_data.summary),
        diagnosis=normalize_text(payload.card_data.analysis),
        advice=normalize_text(payload.card_data.hospital_suggestion),
        department=normalize_text(payload.card_data.recommended_department),
        chat_history=json.dumps([item.model_dump() for item in payload.chat_history], ensure_ascii=False),
        ai_label_meta=build_ai_label_meta(),
        created_at=get_beijing_time()
    )
    db.add(consultation)
    await db.flush()

    update_profile_medical_history(profile, payload.card_data, consultation.created_at)

    await db.commit()
    await db.refresh(consultation)
    await db.refresh(profile)

    return serialize_saved_consultation(consultation, profile)

@router.get("", response_model=List[ConsultationResponse])
async def read_consultations(profile_id: Optional[int] = None, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    stmt = select(ConsultationRecord).join(PatientProfile).where(PatientProfile.user_id == current_user.id)
    if profile_id:
        stmt = stmt.where(ConsultationRecord.profile_id == profile_id)
        
    result = await db.execute(stmt)
    return result.scalars().all()


@router.get("/records", response_model=List[SavedConsultationResponse])
async def read_saved_consultation_records(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = (
        select(ConsultationRecord, PatientProfile)
        .join(PatientProfile, ConsultationRecord.profile_id == PatientProfile.id)
        .where(PatientProfile.user_id == current_user.id)
        .order_by(desc(ConsultationRecord.created_at))
    )
    result = await db.execute(stmt)
    return [serialize_saved_consultation(record, profile) for record, profile in result.all()]


@router.delete("/records/{record_id}")
async def delete_saved_consultation_record(
    request: Request,
    record_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = (
        select(ConsultationRecord, PatientProfile)
        .join(PatientProfile, ConsultationRecord.profile_id == PatientProfile.id)
        .where(
            ConsultationRecord.id == record_id,
            PatientProfile.user_id == current_user.id,
        )
    )
    result = await db.execute(stmt)
    row = result.first()
    if row is None:
        raise HTTPException(status_code=404, detail="Consultation record not found")

    record, profile = row
    remove_profile_medical_history_entry(profile, record)
    await db.delete(record)
    await db.commit()

    await log_operation_safe(
        request=request,
        actor_user=current_user,
        actor_type="user",
        module="consultation",
        action="consultation_record_delete",
        result="success",
        target_type="consultation_record",
        target_id=str(record_id),
        details=f"删除问诊记录：{profile.name}",
        metadata={
            "record_id": record_id,
            "profile_id": profile.id,
            "profile_name": profile.name,
        },
    )
    return {"message": "Consultation record deleted successfully"}
