"""
API 限流中间件

基于 Redis 滑动窗口算法实现，支持按端点配置不同的限流策略。
未认证用户按 IP 限流，已认证用户按 user_id 限流。
"""
import time
from typing import Any, Callable, Dict, Tuple

from fastapi import Request
from fastapi.responses import JSONResponse


# 端点限流配置: (max_requests, window_seconds)
ENDPOINT_LIMITS: Dict[str, Tuple[int, int]] = {
    "/api/iot/subscribe": (10000, 60),
    "/api/auth/login": (10, 60),
    "/api/auth/register": (5, 60),
    "/api/chat": (30, 60),
    "/api/chat/uploads": (20, 60),
}

# 验证码接口在 auth 路由内已经按手机号做 60 秒冷却和每日次数限制。
# 这里不再叠加 IP 维度限制，避免同一医院/公司网络出口下所有手机号互相封锁。
ROUTE_SCOPED_LIMIT_PATHS = {
    "/api/auth/send_code",
}

# 前缀匹配的限流配置
PREFIX_LIMITS: Dict[str, Tuple[int, int]] = {
    "/api/public": (100, 60),
    "/api/admin": (200, 60),
}

DEFAULT_LIMIT = (60, 60)  # 默认: 60 次/分钟
FAIL_CLOSED_PATHS = {
    "/api/auth/login",
    "/api/auth/register",
    "/api/auth/send_code",
    "/api/auth/login/sms",
    "/api/auth/login/carrier",
    "/api/chat",
    "/api/chat/polish",
    "/api/chat/uploads",
    "/api/upload",
}
FAIL_CLOSED_PREFIXES = ("/api/admin", "/api/iot")


class RateLimitMiddleware:
    """Redis 滑动窗口限流中间件。"""

    def __init__(
        self,
        redis_client_getter: Callable[[], Any],
        default_limit: int = 60,
        default_window: int = 60,
    ):
        self._redis_getter = redis_client_getter

    @property
    def client(self) -> Any:
        return self._redis_getter()

    def _get_limits(self, path: str) -> Tuple[int, int]:
        # 精确匹配优先
        if path in ENDPOINT_LIMITS:
            return ENDPOINT_LIMITS[path]
        # 前缀匹配
        for prefix, limits in PREFIX_LIMITS.items():
            if path.startswith(prefix):
                return limits
        return DEFAULT_LIMIT

    def _build_key(self, request: Request) -> str:
        # 优先使用 user_id，否则使用客户端 IP
        token = request.headers.get("Authorization", "")
        if token.startswith("Bearer "):
            try:
                from security import decode_access_token
                payload = decode_access_token(token.replace("Bearer ", "", 1))
                if payload and payload.get("sub"):
                    return f"user:{payload['sub']}"
            except Exception:
                pass

        client_ip = request.client.host if request.client else "unknown"
        return f"ip:{client_ip}"

    async def __call__(self, request: Request, call_next):
        # 跳过非限流请求
        if request.method == "OPTIONS" or request.url.path.startswith("/api/health"):
            return await call_next(request)
        if request.url.path in ROUTE_SCOPED_LIMIT_PATHS:
            return await call_next(request)

        limit, window = self._get_limits(request.url.path)
        key = self._build_key(request)
        now = time.time()
        window_key = f"rate_limit:{key}:{request.url.path}"

        try:
            # 移除窗口外的旧记录
            await self.client.zremrangebyscore(window_key, 0, now - window)
            # 统计当前窗口内的请求数
            count = await self.client.zcard(window_key)

            if count >= limit:
                retry_after = int(window)
                return JSONResponse(
                    status_code=429,
                    content={
                        "detail": "请求过于频繁，请稍后再试",
                        "retry_after": retry_after,
                    },
                    headers={"Retry-After": str(retry_after)},
                )

            # 记录当前请求
            member = f"{now}:{count}"
            await self.client.zadd(window_key, {member: now})
            await self.client.expire(window_key, window + 10)
        except Exception:
            if (
                request.url.path in FAIL_CLOSED_PATHS
                or any(request.url.path.startswith(prefix) for prefix in FAIL_CLOSED_PREFIXES)
            ):
                return JSONResponse(
                    status_code=503,
                    content={"detail": "安全限流服务暂不可用，请稍后重试"},
                )
            # 非敏感接口在 Redis 不可用时继续放行，避免全站不可用。
            pass

        return await call_next(request)
