from datetime import datetime

from fastapi import APIRouter
from fastapi.responses import JSONResponse
from sqlalchemy import text

from database import AsyncSessionLocal, get_redis_client

router = APIRouter(tags=["health"])


@router.get("/api/health")
async def health_liveness():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}


@router.get("/api/health/ready")
async def health_readiness():
    checks = {"database": "ok", "redis": "ok"}
    status_code = 200

    try:
        async with AsyncSessionLocal() as session:
            await session.execute(text("SELECT 1"))
    except Exception as e:
        checks["database"] = f"error: {str(e)}"
        status_code = 503

    try:
        r = get_redis_client()
        await r.ping()
    except Exception as e:
        checks["redis"] = f"error: {str(e)}"
        status_code = 503

    return JSONResponse(
        content={
            "status": "ready" if status_code == 200 else "not_ready",
            "checks": checks,
        },
        status_code=status_code,
    )
