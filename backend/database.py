import os
import hashlib
from typing import Any
from loguru import logger

from dotenv import load_dotenv
from sqlalchemy import Text, inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from db_encryption import (
    decrypt_sensitive_value,
    encrypt_sensitive_value,
    is_encrypted_sensitive_value,
    phone_lookup_hash,
)

load_dotenv()


def _is_truthy_env(value: str | None) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _is_production_env() -> bool:
    return os.getenv("APP_ENV", os.getenv("ENVIRONMENT", "")).strip().lower() in {
        "prod",
        "production",
    }


def _resolve_database_url() -> str:
    database_url = os.getenv("DATABASE_URL", "").strip()
    if not database_url:
        raise RuntimeError(
            "DATABASE_URL 环境变量未设置。请在 .env 文件中配置 PostgreSQL 连接地址。"
        )
    return database_url


DATABASE_URL = _resolve_database_url()
engine = create_async_engine(
    DATABASE_URL,
    echo=_is_truthy_env(os.getenv("SQL_ECHO")),
    pool_size=20,
    max_overflow=10,
    pool_recycle=3600,
    pool_pre_ping=True,
    pool_timeout=30,
    connect_args={
        "server_settings": {"application_name": "hospital-backend"}
    },
)

AsyncSessionLocal = sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False
)

# Read REDIS_URL from environment variables, fallback to fakeredis
REDIS_URL = os.getenv("REDIS_URL", "")

if REDIS_URL.startswith("redis://") or REDIS_URL.startswith("rediss://"):
    import redis.asyncio as redis

    def create_redis_client() -> Any:
        return redis.from_url(
            REDIS_URL,
            decode_responses=True,
            max_connections=20,
            socket_keepalive=True,
            health_check_interval=30,
            retry_on_timeout=True,
        )
else:
    if _is_production_env():
        raise RuntimeError("REDIS_URL must be configured in production")

    from fakeredis import aioredis as fakeredis

    def create_redis_client() -> Any:
        return fakeredis.FakeRedis(decode_responses=True)

redis_client: Any | None = None


def get_redis_client() -> Any:
    global redis_client
    if redis_client is None:
        redis_client = create_redis_client()
    return redis_client


class AuthCache:
    def __init__(self, client_getter):
        self._client_getter = client_getter

    @property
    def client(self) -> Any:
        return self._client_getter()

    @staticmethod
    def sms_count_key(phone: str) -> str:
        return f"sms_count_{phone}"

    @staticmethod
    def sms_code_key(phone: str) -> str:
        return f"sms_code_{phone}"

    @staticmethod
    def sms_cooldown_key(phone: str) -> str:
        return f"sms_cooldown_{phone}"

    @staticmethod
    def login_lock_key(phone: str) -> str:
        return f"lock_{phone}"

    @staticmethod
    def login_attempts_key(phone: str) -> str:
        return f"attempts_{phone}"

    @staticmethod
    def token_blacklist_key(token: str) -> str:
        return f"blacklist_{token}"

    @staticmethod
    def qr_login_key(session_id: str) -> str:
        return f"qr_login:{session_id}"

    @staticmethod
    def hash_qr_secret(value: str) -> str:
        return hashlib.sha256(value.encode("utf-8")).hexdigest()

    async def create_qr_login(
        self,
        *,
        session_id: str,
        qr_token_hash: str,
        pc_secret_hash: str,
        created_at: str,
        expires_at: str,
        ttl_seconds: int,
    ) -> None:
        await self.client.hset(
            self.qr_login_key(session_id),
            mapping={
                "qr_token_hash": qr_token_hash,
                "pc_secret_hash": pc_secret_hash,
                "status": "pending",
                "created_at": created_at,
                "expires_at": expires_at,
            },
        )
        await self.client.expire(self.qr_login_key(session_id), ttl_seconds)

    async def get_qr_login(self, session_id: str) -> dict[str, str]:
        return {
            str(key): str(value)
            for key, value in (
                await self.client.hgetall(self.qr_login_key(session_id))
            ).items()
        }

    async def qr_scan(self, session_id: str, *, user_id: int, scanned_at: str) -> str:
        key = self.qr_login_key(session_id)
        script = """
        local status = redis.call('HGET', KEYS[1], 'status')
        if status == 'pending' then
          redis.call('HSET', KEYS[1], 'status', 'scanned', 'user_id', ARGV[1], 'scanned_at', ARGV[2])
          return 'scanned'
        end
        return status or 'missing'
        """
        result = await self.client.eval(
            script,
            1,
            key,
            str(user_id),
            scanned_at,
        )
        return str(result)

    async def qr_confirm(
        self,
        session_id: str,
        *,
        user_id: int,
        confirmed_at: str,
        access_token: str,
    ) -> str:
        key = self.qr_login_key(session_id)
        script = """
        local status = redis.call('HGET', KEYS[1], 'status')
        local stored_user_id = redis.call('HGET', KEYS[1], 'user_id')
        if status == 'scanned' and stored_user_id == ARGV[1] then
          redis.call('HSET', KEYS[1], 'status', 'confirmed', 'confirmed_at', ARGV[2], 'access_token', ARGV[3])
          return 'confirmed'
        end
        return status or 'missing'
        """
        result = await self.client.eval(
            script,
            1,
            key,
            str(user_id),
            confirmed_at,
            access_token,
        )
        return str(result)

    async def qr_reject(self, session_id: str, *, rejected_at: str) -> str:
        key = self.qr_login_key(session_id)
        script = """
        local status = redis.call('HGET', KEYS[1], 'status')
        if status == 'pending' or status == 'scanned' then
          redis.call('HSET', KEYS[1], 'status', 'rejected', 'rejected_at', ARGV[1])
          return 'rejected'
        end
        return status or 'missing'
        """
        result = await self.client.eval(script, 1, key, rejected_at)
        return str(result)

    async def qr_cancel(self, session_id: str, *, cancelled_at: str) -> str:
        key = self.qr_login_key(session_id)
        script = """
        local status = redis.call('HGET', KEYS[1], 'status')
        if status == 'pending' or status == 'scanned' then
          redis.call('HSET', KEYS[1], 'status', 'cancelled', 'cancelled_at', ARGV[1])
          return 'cancelled'
        end
        return status or 'missing'
        """
        result = await self.client.eval(script, 1, key, cancelled_at)
        return str(result)

    async def qr_consume(self, session_id: str, *, consumed_at: str) -> tuple[str, str | None]:
        key = self.qr_login_key(session_id)
        script = """
        local status = redis.call('HGET', KEYS[1], 'status')
        if status == 'confirmed' then
          local token = redis.call('HGET', KEYS[1], 'access_token')
          redis.call('HSET', KEYS[1], 'status', 'consumed', 'consumed_at', ARGV[1])
          redis.call('HDEL', KEYS[1], 'access_token')
          return {'consumed', token or ''}
        end
        return {status or 'missing', ''}
        """
        result = await self.client.eval(script, 1, key, consumed_at)
        if isinstance(result, (list, tuple)):
            state = str(result[0]) if result else "missing"
            token = str(result[1]) if len(result) > 1 and result[1] else None
            return state, token
        return str(result), None

    async def get_sms_request_count(self, phone: str) -> int:
        count = await self.client.get(self.sms_count_key(phone))
        return int(count) if count else 0

    async def increment_sms_request_count(self, phone: str, ttl_seconds: int) -> int:
        key = self.sms_count_key(phone)
        count = await self.client.incr(key)
        # Always refresh TTL to prevent keys from persisting indefinitely
        await self.client.expire(key, ttl_seconds)
        return count

    async def try_mark_sms_cooldown(self, phone: str, ttl_seconds: int) -> bool:
        result = await self.client.set(
            self.sms_cooldown_key(phone),
            "true",
            ex=ttl_seconds,
            nx=True,
        )
        return bool(result)

    async def clear_sms_cooldown(self, phone: str) -> None:
        await self.client.delete(self.sms_cooldown_key(phone))

    async def store_sms_code(self, phone: str, code: str, ttl_seconds: int) -> None:
        await self.client.setex(self.sms_code_key(phone), ttl_seconds, code)

    async def get_sms_code(self, phone: str) -> str | None:
        code = await self.client.get(self.sms_code_key(phone))
        return str(code) if code else None

    async def delete_sms_code(self, phone: str) -> None:
        await self.client.delete(self.sms_code_key(phone))

    async def is_login_locked(self, phone: str) -> bool:
        return bool(await self.client.get(self.login_lock_key(phone)))

    async def register_failed_login(
        self,
        phone: str,
        max_attempts: int,
        lock_ttl_seconds: int,
    ) -> bool:
        attempts = await self.client.incr(self.login_attempts_key(phone))
        if attempts >= max_attempts:
            await self.client.setex(
                self.login_lock_key(phone),
                lock_ttl_seconds,
                "locked",
            )
            await self.client.delete(self.login_attempts_key(phone))
            return True
        return False

    async def reset_failed_logins(self, phone: str) -> None:
        await self.client.delete(self.login_attempts_key(phone))

    async def blacklist_token(self, token: str, ttl_seconds: int) -> None:
        await self.client.setex(
            self.token_blacklist_key(token),
            ttl_seconds,
            "true",
        )

    async def is_token_blacklisted(self, token: str) -> bool:
        return bool(await self.client.get(self.token_blacklist_key(token)))


auth_cache = AuthCache(get_redis_client)


def get_database_dialect() -> str:
    return engine.url.get_backend_name()


def get_masked_database_url() -> str:
    try:
        url = make_url(DATABASE_URL)
    except Exception:
        return "<invalid DATABASE_URL>"

    return str(url.render_as_string(hide_password=True))


async def check_redis_connection() -> None:
    global redis_client
    client = get_redis_client()
    try:
        await client.ping()
    except Exception as e:
        if _is_production_env():
            logger.error(f"Redis connection failed in production: {e}")
            raise

        from fakeredis import aioredis as fakeredis

        redis_client = fakeredis.FakeRedis(decode_responses=True)
        # Update auth_cache to use the new fakeredis client
        auth_cache._client_getter = get_redis_client
        await redis_client.ping()
        logger.error(f"Redis connection failed, fallback to fakeredis: {e}")


async def close_redis_connection() -> None:
    global redis_client
    if redis_client is None:
        return
    try:
        if hasattr(redis_client, "aclose"):
            await redis_client.aclose()
        elif hasattr(redis_client, "close"):
            close_result = redis_client.close()
            if hasattr(close_result, "__await__"):
                await close_result
    except Exception as e:
        logger.error(f"Failed to close Redis connection: {e}")
    finally:
        redis_client = None


async def close_db_connections() -> None:
    await engine.dispose()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session

def _ensure_user_account_status_column(connection) -> None:
    inspector = inspect(connection)
    if "users" not in inspector.get_table_names():
        return

    columns = {column["name"] for column in inspector.get_columns("users")}
    dialect = connection.dialect.name
    true_literal = "TRUE" if dialect == "postgresql" else "1"

    if "deactivated_at" not in columns:
        if dialect == "postgresql":
            connection.execute(text("ALTER TABLE users ADD COLUMN deactivated_at TIMESTAMP NULL"))
        else:
            connection.execute(text("ALTER TABLE users ADD COLUMN deactivated_at DATETIME NULL"))
        logger.info("Added missing users.deactivated_at column.")

    if "is_active" not in columns:
        if dialect == "postgresql":
            connection.execute(
                text("ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE")
            )
        else:
            connection.execute(text("ALTER TABLE users ADD COLUMN is_active BOOLEAN DEFAULT 1"))
        logger.info("Added missing users.is_active column.")
        return

    connection.execute(
        text(f"UPDATE users SET is_active = {true_literal} WHERE is_active IS NULL")
    )


def _ensure_audit_log_columns(connection) -> None:
    inspector = inspect(connection)
    if "audit_logs" not in inspector.get_table_names():
        return

    columns = {column["name"] for column in inspector.get_columns("audit_logs")}
    column_definitions = {
        "actor_user_id": "INTEGER",
        "actor_type": "VARCHAR(20)",
        "actor_name": "VARCHAR(100)",
        "actor_phone_masked": "VARCHAR(20)",
        "terminal": "VARCHAR(20)",
        "module": "VARCHAR(50)",
        "result": "VARCHAR(20)",
        "target_type": "VARCHAR(50)",
        "ip_address": "VARCHAR(64)",
        "user_agent": "VARCHAR(300)",
        "request_id": "VARCHAR(64)",
        "metadata_json": "TEXT",
    }

    for column_name, column_type in column_definitions.items():
        if column_name in columns:
            continue
        connection.execute(
            text(f"ALTER TABLE audit_logs ADD COLUMN {column_name} {column_type}")
        )
        logger.info("Added missing audit_logs.{} column.", column_name)


def _has_index(connection, table_name: str, index_name: str) -> bool:
    inspector = inspect(connection)
    return index_name in {
        index["name"] for index in inspector.get_indexes(table_name)
    }


def _column_is_text(connection, table_name: str, column_name: str) -> bool:
    inspector = inspect(connection)
    for column in inspector.get_columns(table_name):
        if column["name"] == column_name:
            return isinstance(column["type"], (Text,))
    return False


def _ensure_sensitive_column_shapes(connection) -> None:
    inspector = inspect(connection)
    tables = set(inspector.get_table_names())
    dialect = connection.dialect.name

    if "users" in tables:
        user_columns = {column["name"] for column in inspector.get_columns("users")}
        if "phone_hash" not in user_columns:
            connection.execute(text("ALTER TABLE users ADD COLUMN phone_hash VARCHAR(64)"))
            logger.info("Added missing users.phone_hash column.")
        if dialect == "postgresql" and not _column_is_text(connection, "users", "phone"):
            connection.execute(text("ALTER TABLE users ALTER COLUMN phone TYPE TEXT"))

    if (
        "patient_profiles" in tables
        and dialect == "postgresql"
        and not _column_is_text(connection, "patient_profiles", "name")
    ):
        connection.execute(text("ALTER TABLE patient_profiles ALTER COLUMN name TYPE TEXT"))


def _migrate_user_phone_encryption(connection) -> None:
    inspector = inspect(connection)
    if "users" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("users")}
    if "phone" not in columns or "phone_hash" not in columns:
        return

    has_deactivated_at = "deactivated_at" in columns
    rows = connection.execute(
        text("SELECT id, phone, phone_hash, is_active, deactivated_at FROM users ORDER BY id")
        if has_deactivated_at
        else text("SELECT id, phone, phone_hash, is_active, NULL AS deactivated_at FROM users ORDER BY id")
    ).mappings().all()
    assigned_phone_hashes = {
        row["phone_hash"]: row["id"]
        for row in rows
        if row["phone_hash"]
    }
    updated_count = 0
    for row in rows:
        # 已注销账号的手机号已释放（phone_hash 为空），不再回填，避免与新建账号冲突。
        if row["deactivated_at"] is not None:
            continue
        stored_phone = row["phone"]
        plain_phone = decrypt_sensitive_value(stored_phone)
        if not plain_phone:
            logger.warning("Skipped users.{} phone encryption because value cannot be decrypted.", row["id"])
            continue

        encrypted_phone = (
            stored_phone
            if is_encrypted_sensitive_value(stored_phone)
            else encrypt_sensitive_value(plain_phone)
        )
        lookup_hash = phone_lookup_hash(plain_phone)
        next_phone_hash = lookup_hash
        hash_owner_id = assigned_phone_hashes.get(lookup_hash)
        if hash_owner_id is not None and hash_owner_id != row["id"]:
            next_phone_hash = row["phone_hash"]
            logger.warning(
                "Skipped users.{} phone_hash refresh because the same phone hash is already used by users.{}.",
                row["id"],
                hash_owner_id,
            )
        else:
            assigned_phone_hashes[lookup_hash] = row["id"]

        if stored_phone == encrypted_phone and row["phone_hash"] == next_phone_hash:
            continue

        connection.execute(
            text(
                "UPDATE users "
                "SET phone = :phone, phone_hash = :phone_hash "
                "WHERE id = :id"
            ),
            {"id": row["id"], "phone": encrypted_phone, "phone_hash": next_phone_hash},
        )
        updated_count += 1

    if updated_count:
        logger.info("Encrypted users.phone and refreshed users.phone_hash for {} rows.", updated_count)


def _migrate_profile_name_encryption(connection) -> None:
    inspector = inspect(connection)
    if "patient_profiles" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("patient_profiles")}
    if "name" not in columns:
        return

    rows = connection.execute(text("SELECT id, name FROM patient_profiles")).mappings().all()
    updated_count = 0
    for row in rows:
        stored_name = row["name"]
        plain_name = decrypt_sensitive_value(stored_name)
        if not plain_name:
            logger.warning(
                "Skipped patient_profiles.{} name encryption because value cannot be decrypted.",
                row["id"],
            )
            continue

        encrypted_name = (
            stored_name
            if is_encrypted_sensitive_value(stored_name)
            else encrypt_sensitive_value(plain_name)
        )
        if stored_name == encrypted_name:
            continue

        connection.execute(
            text("UPDATE patient_profiles SET name = :name WHERE id = :id"),
            {"id": row["id"], "name": encrypted_name},
        )
        updated_count += 1

    if updated_count:
        logger.info("Encrypted patient_profiles.name for {} rows.", updated_count)


def _ensure_user_phone_hash_index(connection) -> None:
    inspector = inspect(connection)
    if "users" not in inspector.get_table_names():
        return
    if "phone_hash" not in {column["name"] for column in inspector.get_columns("users")}:
        return
    duplicate_count = connection.execute(
        text(
            "SELECT COUNT(*) FROM ("
            "SELECT phone_hash FROM users "
            "WHERE phone_hash IS NOT NULL "
            "GROUP BY phone_hash HAVING COUNT(*) > 1"
            ") duplicated_phone_hashes"
        )
    ).scalar()
    if duplicate_count:
        logger.warning(
            "Skipped users.phone_hash unique index because {} duplicate phone hash group(s) exist.",
            duplicate_count,
        )
        return
    if not _has_index(connection, "users", "ix_users_phone_hash"):
        connection.execute(
            text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_phone_hash ON users (phone_hash)")
        )
        logger.info("Created users.phone_hash unique index.")


def _normalize_deactivated_phone_hashes(connection) -> None:
    """一次性适配：旧版注销账号补填 deactivated_at，并释放已注销账号的手机号。"""
    inspector = inspect(connection)
    if "users" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("users")}
    if "deactivated_at" not in columns or "phone_hash" not in columns:
        return

    dialect = connection.dialect.name
    false_literal = "FALSE" if dialect == "postgresql" else "0"

    # 旧版注销只置 is_active=False 并把昵称改为"已注销用户"，没有 deactivated_at。
    # 这里补填 deactivated_at，让这些账号按"永久注销"语义处理（手机号随后释放）。
    if "is_active" in columns and "display_name" in columns:
        backfill = connection.execute(
            text(
                "UPDATE users SET deactivated_at = CURRENT_TIMESTAMP "
                "WHERE deactivated_at IS NULL AND is_active = "
                f"{false_literal} AND display_name = '已注销用户'"
            )
        )
        if backfill.rowcount:
            logger.info(
                "Marked {} legacy deactivated account(s) with deactivated_at.",
                backfill.rowcount,
            )
    result = connection.execute(
        text(
            "UPDATE users SET phone_hash = NULL "
            "WHERE deactivated_at IS NOT NULL AND phone_hash IS NOT NULL"
        )
    )
    if result.rowcount:
        logger.info(
            "Released phone_hash for {} deactivated user(s) so the phone can register anew.",
            result.rowcount,
        )


def _ensure_sensitive_data_encryption(connection) -> None:
    _ensure_sensitive_column_shapes(connection)
    _migrate_user_phone_encryption(connection)
    _migrate_profile_name_encryption(connection)
    _ensure_user_phone_hash_index(connection)
    _normalize_deactivated_phone_hashes(connection)


def _ensure_consultation_ai_label_meta_column(connection) -> None:
    """为已存在的数据库补齐 AI 标识列；新库由 ORM create_all 创建。"""
    inspector = inspect(connection)
    if "consultation_records" not in inspector.get_table_names():
        return
    columns = {column["name"] for column in inspector.get_columns("consultation_records")}
    if "ai_label_meta" in columns:
        return

    column_type = "JSONB" if connection.dialect.name == "postgresql" else "JSON"
    connection.execute(
        text(f"ALTER TABLE consultation_records ADD COLUMN ai_label_meta {column_type}")
    )

async def init_db():
    from models import Base
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.run_sync(_ensure_user_account_status_column)
        await conn.run_sync(_ensure_audit_log_columns)
        await conn.run_sync(_ensure_consultation_ai_label_meta_column)
        await conn.run_sync(_ensure_sensitive_data_encryption)


async def seed_default_data():
    """Seed default system configs and agreements using ORM (dialect-safe)."""
    from models import SystemConfig, Agreement
    from sqlalchemy import select as sa_select

    async with AsyncSessionLocal() as session:
        # Seed system configs
        existing_configs = await session.execute(
            sa_select(SystemConfig.key).where(
                SystemConfig.key.in_(["high_freq_threshold", "system_name"])
            )
        )
        existing_keys = {row[0] for row in existing_configs}
        if "high_freq_threshold" not in existing_keys:
            session.add(SystemConfig(key="high_freq_threshold", value="10", description="高频问题单日提问阈值"))
        if "system_name" not in existing_keys:
            session.add(SystemConfig(key="system_name", value="AI 医疗问诊后台", description="系统名称"))

        # Seed agreements
        existing_agreements = await session.execute(
            sa_select(Agreement.type).where(
                Agreement.type.in_(["user_agreement", "privacy_policy"])
            )
        )
        existing_agreement_types = {row[0] for row in existing_agreements}
        if "user_agreement" not in existing_agreement_types:
            session.add(Agreement(
                type="user_agreement",
                title="用户协议",
                content="# 欢迎使用我们的服务\n\n请仔细阅读用户协议。\n\n1. **服务条款**\n2. **隐私保护**"
            ))
        if "privacy_policy" not in existing_agreement_types:
            session.add(Agreement(
                type="privacy_policy",
                title="隐私政策",
                content="# 隐私政策\n\n我们非常重视您的隐私保护。\n\n- 数据收集\n- 数据使用"
            ))

        await session.commit()
