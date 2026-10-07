import csv
import io

from fastapi import APIRouter, Depends, Query, UploadFile, File, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import desc, select, func
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from dependencies import get_current_admin
from models import User
from safety.guard import check_input
from safety.models import AiSafetyEvent, AiIntentRule, AiSensitiveWord, AiSafetyTestCase
from safety.intent import configure_dynamic_intents
from safety.wordbank import configure_dynamic_words

router = APIRouter(prefix="/api/admin/ai-safety", tags=["ai-safety"])

async def _list_create(model, payload, db, offset=0, limit=100):
    if payload is not None:
        item = model(**payload)
        db.add(item)
        await db.commit()
        await db.refresh(item)
        return item
    result = await db.execute(select(model).offset(offset).limit(limit))
    return result.scalars().all()

def _serialize(item):
    data = {column.name: getattr(item, column.name) for column in item.__table__.columns}
    for key, value in data.items():
        if hasattr(value, "isoformat"):
            data[key] = value.isoformat()
    return data


async def _reload_dynamic_rules(db: AsyncSession):
    intents = (await db.execute(
        select(AiIntentRule).where(AiIntentRule.status == "enabled").order_by(AiIntentRule.priority, AiIntentRule.id)
    )).scalars().all()
    words = (await db.execute(
        select(AiSensitiveWord).where(AiSensitiveWord.status == "enabled").order_by(AiSensitiveWord.priority, AiSensitiveWord.id)
    )).scalars().all()
    configure_dynamic_intents(intents)
    configure_dynamic_words(words)


INTENT_FIELDS = {"scene_name", "intent_code", "risk_level", "triggers", "match_mode", "reply_template", "action", "scope", "priority", "status", "remark"}
WORD_FIELDS = {"category", "content", "match_mode", "action", "reply_template", "apply_phase", "scope", "risk_level", "whitelist_context", "priority", "status", "source_version"}


def _clean_payload(payload: dict, fields: set[str]):
    return {key: value for key, value in payload.items() if key in fields}

@router.post("/check")
async def debug_check(payload: dict, _admin: User = Depends(get_current_admin)):
    decision = check_input(str(payload.get("text", "")), payload.get("history"), str(payload.get("scope", "all")))
    return {
        "intent_code": decision.intent_code,
        "risk_level": decision.risk_level,
        "action": decision.action,
        "reply_template": decision.reply_template,
        "matched_rules": decision.matched_rules,
        "decision_id": decision.decision_id,
    }

@router.get("/events")
async def list_events(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    phase: str | None = None,
    risk_level: str | None = None,
    keyword: str | None = None,
    _admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AiSafetyEvent).order_by(desc(AiSafetyEvent.created_at))
    if phase:
        stmt = stmt.where(AiSafetyEvent.phase == phase)
    if risk_level:
        stmt = stmt.where(AiSafetyEvent.risk_level == risk_level)
    if keyword:
        stmt = stmt.where(AiSafetyEvent.excerpt.ilike(f"%{keyword}%"))
    total = (await db.execute(select(func.count()).select_from(stmt.subquery()))).scalar_one()
    result = await db.execute(stmt.offset((page - 1) * page_size).limit(page_size))
    items = result.scalars().all()
    return {"items": [{"id": item.id, "user_id": item.user_id, "terminal": item.terminal, "scene": item.scene, "phase": item.phase, "intent_code": item.intent_code, "category": item.category, "risk_level": item.risk_level, "action": item.action, "matched_rules": item.matched_rules_json, "excerpt": item.excerpt, "reply_text": item.reply_text, "violation_reason": ((item.matched_rules_json or [{}])[0].get("name") if item.matched_rules_json else None), "review_status": item.review_status, "created_at": item.created_at.isoformat() if item.created_at else None} for item in items], "page": page, "page_size": page_size, "total": total}

@router.get("/events/stats")
async def event_stats(_admin: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(AiSafetyEvent.risk_level, func.count(AiSafetyEvent.id)).group_by(AiSafetyEvent.risk_level))
    return {"items": [{"risk_level": level, "count": count} for level, count in result.all()]}


@router.get("/intent-rules")
async def list_intent_rules(
    status: str | None = None,
    risk_level: str | None = None,
    intent_code: str | None = None,
    keyword: str | None = None,
    _admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AiIntentRule).order_by(AiIntentRule.priority, AiIntentRule.id)
    if status:
        stmt = stmt.where(AiIntentRule.status == status)
    if risk_level:
        stmt = stmt.where(AiIntentRule.risk_level == risk_level)
    if intent_code:
        stmt = stmt.where(AiIntentRule.intent_code == intent_code)
    if keyword:
        stmt = stmt.where(AiIntentRule.triggers.ilike(f"%{keyword}%"))
    items = (await db.execute(stmt)).scalars().all()
    return {"items": [_serialize(item) for item in items], "total": len(items)}


@router.get("/words")
async def list_words(
    status: str | None = None,
    category: str | None = None,
    risk_level: str | None = None,
    keyword: str | None = None,
    _admin: User = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AiSensitiveWord).order_by(AiSensitiveWord.priority, AiSensitiveWord.id)
    if status:
        stmt = stmt.where(AiSensitiveWord.status == status)
    if category:
        stmt = stmt.where(AiSensitiveWord.category == category)
    if risk_level:
        stmt = stmt.where(AiSensitiveWord.risk_level == risk_level)
    if keyword:
        stmt = stmt.where(AiSensitiveWord.content.ilike(f"%{keyword}%"))
    items = (await db.execute(stmt)).scalars().all()
    return {"items": [_serialize(item) for item in items], "total": len(items)}


@router.post("/words/batch-status")
async def batch_word_status(payload: dict, _admin: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db)):
    ids = payload.get("ids", [])
    status = str(payload.get("status", ""))
    if status not in {"enabled", "disabled"} or not isinstance(ids, list):
        raise HTTPException(status_code=400, detail="ids and status are invalid")
    count = 0
    for item_id in ids:
        item = await db.get(AiSensitiveWord, int(item_id))
        if item:
            item.status = status
            count += 1
    await db.commit()
    await _reload_dynamic_rules(db)
    return {"ok": True, "updated": count}


@router.post("/words/import")
async def import_words(file: UploadFile = File(...), _admin: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db)):
    raw = await file.read()
    try:
        reader = csv.DictReader(io.StringIO(raw.decode("utf-8-sig")))
        rows = list(reader)
    except (UnicodeDecodeError, csv.Error) as exc:
        raise HTTPException(status_code=400, detail="CSV file is invalid") from exc
    required = {"category", "content", "action", "risk_level"}
    if not rows or not required.issubset(set(rows[0].keys() or [])):
        raise HTTPException(status_code=400, detail="CSV must include category, content, action, risk_level")
    created = 0
    for row in rows:
        values = _clean_payload(row, WORD_FIELDS)
        if not values.get("content"):
            continue
        values["priority"] = int(values.get("priority") or 100)
        db.add(AiSensitiveWord(**values))
        created += 1
    await db.commit()
    await _reload_dynamic_rules(db)
    return {"ok": True, "created": created}


@router.get("/words/export")
async def export_words(_admin: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db)):
    items = (await db.execute(select(AiSensitiveWord).order_by(AiSensitiveWord.priority, AiSensitiveWord.id))).scalars().all()
    fields = ["category", "content", "match_mode", "action", "reply_template", "apply_phase", "scope", "risk_level", "whitelist_context", "priority", "status", "source_version"]
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fields)
    writer.writeheader()
    for item in items:
        writer.writerow({field: getattr(item, field) or "" for field in fields})
    return StreamingResponse(iter([output.getvalue().encode("utf-8-sig")]), media_type="text/csv", headers={"Content-Disposition": "attachment; filename=ai_sensitive_words.csv"})

@router.get("/{resource}")
async def list_resource(resource: str, _admin: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db)):
    model = {"intent-rules": AiIntentRule, "words": AiSensitiveWord, "test-cases": AiSafetyTestCase}.get(resource)
    if model is None:
        return {"items": []}
    return {"items": [_serialize(item) for item in await _list_create(model, None, db)]}

@router.post("/{resource}")
async def create_resource(resource: str, payload: dict, _admin: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db)):
    model = {"intent-rules": AiIntentRule, "words": AiSensitiveWord, "test-cases": AiSafetyTestCase}.get(resource)
    if model is None:
        return {"detail": "Unknown safety resource"}
    fields = INTENT_FIELDS if model is AiIntentRule else WORD_FIELDS if model is AiSensitiveWord else set(payload)
    item = await _list_create(model, _clean_payload(payload, fields), db)
    if model in {AiIntentRule, AiSensitiveWord}:
        await _reload_dynamic_rules(db)
    return _serialize(item)

@router.put("/{resource}/{item_id}")
async def update_resource(resource: str, item_id: int, payload: dict, _admin: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db)):
    model = {"intent-rules": AiIntentRule, "words": AiSensitiveWord, "test-cases": AiSafetyTestCase}.get(resource)
    if model is None:
        return {"detail": "Unknown safety resource"}
    item = await db.get(model, item_id)
    if item is None:
        return {"detail": "Not found"}
    fields = INTENT_FIELDS if model is AiIntentRule else WORD_FIELDS if model is AiSensitiveWord else set(payload)
    for key, value in _clean_payload(payload, fields).items():
        if hasattr(item, key):
            setattr(item, key, value)
    await db.commit()
    await db.refresh(item)
    if model in {AiIntentRule, AiSensitiveWord}:
        await _reload_dynamic_rules(db)
    return _serialize(item)

@router.delete("/{resource}/{item_id}")
async def delete_resource(resource: str, item_id: int, _admin: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db)):
    model = {"intent-rules": AiIntentRule, "words": AiSensitiveWord, "test-cases": AiSafetyTestCase}.get(resource)
    if model is None:
        return {"detail": "Unknown safety resource"}
    item = await db.get(model, item_id)
    if item is None:
        return {"detail": "Not found"}
    await db.delete(item)
    await db.commit()
    if model in {AiIntentRule, AiSensitiveWord}:
        await _reload_dynamic_rules(db)
    return {"ok": True}

@router.post("/events/{event_id}/review")
async def review_event(event_id: int, payload: dict, _admin: User = Depends(get_current_admin), db: AsyncSession = Depends(get_db)):
    item = await db.get(AiSafetyEvent, event_id)
    if item is None:
        return {"detail": "Not found"}
    item.review_status = str(payload.get("review_status", "reviewed"))
    await db.commit()
    return {"ok": True, "review_status": item.review_status}
