"""
两级缓存层

L1: 进程内 TTLCache（cachetools），适用于热点小数据
L2: Redis 缓存，适用于跨进程共享数据
"""
import json
import os
from typing import Any, Optional

from cachetools import TTLCache
from loguru import logger

from database import get_redis_client

# ── L1: 进程内 TTL 缓存 ──
l1_cache: TTLCache = TTLCache(maxsize=500, ttl=300)


def l1_get(key: str) -> Optional[Any]:
    try:
        return l1_cache.get(key)
    except KeyError:
        return None


def l1_set(key: str, value: Any, ttl: int = 300) -> None:
    l1_cache[key] = value


def l1_delete(key: str) -> None:
    try:
        del l1_cache[key]
    except KeyError:
        pass


def l1_clear_prefix(prefix: str) -> None:
    """清除 L1 中所有匹配前缀的缓存。"""
    keys_to_delete = [k for k in l1_cache if k.startswith(prefix)]
    for k in keys_to_delete:
        try:
            del l1_cache[k]
        except KeyError:
            pass


# ── L2: Redis 缓存 ──
class RedisCache:
    """Redis 缓存封装。"""

    def __init__(self, default_ttl: int = 300):
        self._default_ttl = default_ttl

    @property
    def client(self):
        return get_redis_client()

    async def get(self, key: str) -> Optional[str]:
        try:
            value = await self.client.get(f"cache:{key}")
            return value
        except Exception as e:
            logger.warning(f"Redis cache get failed for key '{key}': {e}")
            return None

    async def get_json(self, key: str) -> Optional[Any]:
        value = await self.get(key)
        if value:
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                return None
        return None

    async def set(self, key: str, value: str, ttl: int = None) -> None:
        try:
            ttl = ttl or self._default_ttl
            await self.client.setex(f"cache:{key}", ttl, value)
        except Exception as e:
            logger.warning(f"Redis cache set failed for key '{key}': {e}")

    async def set_json(self, key: str, value: Any, ttl: int = None) -> None:
        await self.set(key, json.dumps(value, ensure_ascii=False), ttl)

    async def delete(self, key: str) -> None:
        try:
            await self.client.delete(f"cache:{key}")
        except Exception as e:
            logger.warning(f"Redis cache delete failed for key '{key}': {e}")

    async def delete_pattern(self, pattern: str) -> None:
        """批量清除匹配模式的缓存键。"""
        try:
            keys = []
            cursor = 0
            while True:
                cursor, batch = await self.client.scan(
                    cursor, match=f"cache:{pattern}", count=100
                )
                keys.extend(batch)
                if cursor == 0:
                    break
            if keys:
                await self.client.delete(*keys)
        except Exception as e:
            logger.warning(f"Redis cache delete_pattern failed for '{pattern}': {e}")


# ── 高级缓存读写 ──
_redis_cache = RedisCache()


async def cache_get(key: str, use_l1: bool = True) -> Optional[Any]:
    """读取缓存（L1 → L2 穿透）。"""
    prefix = "cache:"

    # L1
    if use_l1:
        value = l1_get(key)
        if value is not None:
            return value

    # L2
    value = await _redis_cache.get_json(key)
    if value is not None and use_l1:
        l1_set(key, value)
    return value


async def cache_set(key: str, value: Any, ttl: int = 300, use_l1: bool = True) -> None:
    """写入缓存（L1 + L2）。"""
    if use_l1:
        l1_set(key, value, ttl)
    await _redis_cache.set_json(key, value, ttl)


async def cache_invalidate(key: str) -> None:
    """清除指定键的 L1 和 L2 缓存。"""
    l1_delete(key)
    await _redis_cache.delete(key)


async def cache_invalidate_pattern(pattern: str) -> None:
    """批量清除匹配模式的缓存。"""
    l1_clear_prefix(pattern.rstrip("*"))
    await _redis_cache.delete_pattern(pattern)
