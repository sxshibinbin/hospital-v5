from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from models import PatientProfile, User
from database import get_db
from dependencies import get_current_user
from operation_log_service import log_operation_safe
from security import encrypt_data, decrypt_data
from pydantic import BaseModel
from typing import List, Optional

router = APIRouter(prefix="/api/profiles", tags=["profiles"])

class ProfileBase(BaseModel):
    name: str
    relation: str
    gender: str
    age: int
    medical_history: Optional[str] = None
    allergies: Optional[str] = None

class ProfileCreate(ProfileBase):
    pass

class ProfileResponse(ProfileBase):
    id: int

    class Config:
        from_attributes = True


def _profile_summary(profile: PatientProfile) -> str:
    relation = (profile.relation or "").strip()
    if relation:
        return f"{profile.name}（{relation}）"
    return profile.name

@router.post("", response_model=ProfileResponse)
async def create_profile(
    request: Request,
    profile: ProfileCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    db_profile = PatientProfile(
        user_id=current_user.id,
        name=profile.name,
        relation=profile.relation,
        gender=profile.gender,
        age=profile.age,
        medical_history=encrypt_data(profile.medical_history),
        allergies=encrypt_data(profile.allergies)
    )
    db.add(db_profile)
    await db.commit()
    await db.refresh(db_profile)

    await log_operation_safe(
        request=request,
        actor_user=current_user,
        actor_type="user",
        module="profile",
        action="profile_create",
        result="success",
        target_type="patient_profile",
        target_id=str(db_profile.id),
        details=f"新增健康档案：{_profile_summary(db_profile)}",
        metadata={
            "profile_id": db_profile.id,
            "profile_name": db_profile.name,
            "relation": db_profile.relation,
        },
    )
    
    # Decrypt for response
    db_profile.medical_history = decrypt_data(db_profile.medical_history)
    db_profile.allergies = decrypt_data(db_profile.allergies)
    return db_profile

@router.get("", response_model=List[ProfileResponse])
async def read_profiles(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    stmt = select(PatientProfile).where(PatientProfile.user_id == current_user.id)
    result = await db.execute(stmt)
    profiles = result.scalars().all()
    
    for p in profiles:
        p.medical_history = decrypt_data(p.medical_history)
        p.allergies = decrypt_data(p.allergies)
        
    return profiles

@router.put("/{profile_id}", response_model=ProfileResponse)
async def update_profile(
    request: Request,
    profile_id: int,
    profile: ProfileCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(PatientProfile).where(PatientProfile.id == profile_id, PatientProfile.user_id == current_user.id)
    result = await db.execute(stmt)
    db_profile = result.scalars().first()
    
    if db_profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
        
    db_profile.name = profile.name
    db_profile.relation = profile.relation
    db_profile.gender = profile.gender
    db_profile.age = profile.age
    db_profile.medical_history = encrypt_data(profile.medical_history)
    db_profile.allergies = encrypt_data(profile.allergies)
    
    await db.commit()
    await db.refresh(db_profile)

    await log_operation_safe(
        request=request,
        actor_user=current_user,
        actor_type="user",
        module="profile",
        action="profile_update",
        result="success",
        target_type="patient_profile",
        target_id=str(db_profile.id),
        details=f"修改健康档案：{_profile_summary(db_profile)}",
        metadata={
            "profile_id": db_profile.id,
            "profile_name": db_profile.name,
            "relation": db_profile.relation,
        },
    )
    
    db_profile.medical_history = decrypt_data(db_profile.medical_history)
    db_profile.allergies = decrypt_data(db_profile.allergies)
    return db_profile

@router.delete("/{profile_id}")
async def delete_profile(
    request: Request,
    profile_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(PatientProfile).where(PatientProfile.id == profile_id, PatientProfile.user_id == current_user.id)
    result = await db.execute(stmt)
    db_profile = result.scalars().first()
    
    if db_profile is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    profile_summary = _profile_summary(db_profile)
    await db.delete(db_profile)
    await db.commit()

    await log_operation_safe(
        request=request,
        actor_user=current_user,
        actor_type="user",
        module="profile",
        action="profile_delete",
        result="success",
        target_type="patient_profile",
        target_id=str(profile_id),
        details=f"删除健康档案：{profile_summary}",
        metadata={
            "profile_id": profile_id,
            "profile_name": db_profile.name,
            "relation": db_profile.relation,
        },
    )
    return {"message": "Profile deleted successfully"}
