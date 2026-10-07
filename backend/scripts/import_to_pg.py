"""
JSON → PostgreSQL 数据导入脚本

从 scripts/exported_data/ 的 JSON 文件中读取数据，
导入到 PostgreSQL 数据库中。

必须先运行 alembic upgrade head 创建表结构。
需要设置 DATABASE_URL 环境变量指向 PostgreSQL。

用法: python scripts/import_to_pg.py
"""
import asyncio
import json
import os
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from dotenv import load_dotenv
from db_encryption import (
    decrypt_sensitive_value,
    encrypt_sensitive_value,
    is_encrypted_sensitive_value,
    phone_lookup_hash,
)

OUTPUT_DIR = Path(__file__).resolve().parent / "exported_data"

load_dotenv()

# 导入顺序遵循外键依赖
TABLES = [
    "users",
    "patient_profiles",
    "consultation_records",
    "chat_sessions",
    "high_freq_questions",
    "system_configs",
    "audit_logs",
    "agreements",
]

# 需要重置序列的表（自增主键）
SEQUENCE_TABLES = [
    "users",
    "patient_profiles",
    "consultation_records",
    "chat_sessions",
    "high_freq_questions",
    "system_configs",
    "audit_logs",
    "agreements",
]


def prepare_sensitive_rows(table: str, rows: list[dict]) -> None:
    if table == "users":
        for row in rows:
            row.setdefault("phone_hash", None)
            stored_phone = row.get("phone")
            plain_phone = decrypt_sensitive_value(stored_phone)
            if not plain_phone:
                continue
            row["phone"] = (
                stored_phone
                if is_encrypted_sensitive_value(stored_phone)
                else encrypt_sensitive_value(plain_phone)
            )
            row["phone_hash"] = row.get("phone_hash") or phone_lookup_hash(plain_phone)
        return

    if table == "patient_profiles":
        for row in rows:
            stored_name = row.get("name")
            plain_name = decrypt_sensitive_value(stored_name)
            if not plain_name:
                continue
            row["name"] = (
                stored_name
                if is_encrypted_sensitive_value(stored_name)
                else encrypt_sensitive_value(plain_name)
            )


async def import_table(table: str) -> int:
    """从 JSON 文件导入单张表到 PostgreSQL，返回导入的行数。"""
    json_path = OUTPUT_DIR / f"{table}.json"
    if not json_path.exists():
        print(f"  ⚠ {table}: 跳过 (JSON 文件不存在)")
        return 0

    with open(json_path, "r", encoding="utf-8") as f:
        rows = json.load(f)

    if not rows:
        print(f"  ✓ {table}: 0 行 (空表)")
        return 0

    prepare_sensitive_rows(table, rows)

    from database import AsyncSessionLocal

    async with AsyncSessionLocal() as session:
        from sqlalchemy import text

        # 使用原生 INSERT 批量导入
        columns = list(rows[0].keys())
        col_names = ", ".join(columns)
        placeholders = ", ".join([f":{col}" for col in columns])

        # 分批导入，每批 500 条
        batch_size = 500
        for i in range(0, len(rows), batch_size):
            batch = rows[i : i + batch_size]
            values_sql = ", ".join(
                [
                    f"({', '.join([f':{col}_{i+j}' for col in columns])})"
                    for j in range(len(batch))
                ]
            )

            params = {}
            for j, row in enumerate(batch):
                for col in columns:
                    params[f"{col}_{i+j}"] = row[col]

            sql = f"INSERT INTO {table} ({col_names}) VALUES {values_sql} ON CONFLICT DO NOTHING"
            try:
                await session.execute(text(sql), params)
            except Exception as e:
                print(f"  ✗ {table}: 导入失败 - {e}")
                await session.rollback()
                return 0

        await session.commit()

    return len(rows)


async def reset_sequences():
    """重置所有表的自增序列，确保后续插入的 ID 从正确值开始。"""
    from database import AsyncSessionLocal

    async with AsyncSessionLocal() as session:
        from sqlalchemy import text

        for table in SEQUENCE_TABLES:
            seq_name = f"{table}_id_seq"
            try:
                await session.execute(
                    text(
                        f"SELECT setval('{seq_name}', COALESCE((SELECT MAX(id) FROM {table}), 0))"
                    )
                )
            except Exception:
                pass  # 序列可能不存在，跳过
        await session.commit()


async def main():
    if not OUTPUT_DIR.exists():
        print(f"错误: 找不到导出数据目录: {OUTPUT_DIR}")
        print("请先运行: python scripts/export_sqlite.py")
        return

    total_rows = 0
    for table in TABLES:
        count = await import_table(table)
        total_rows += count
        if count > 0:
            print(f"  ✓ {table}: {count} 行")

    await reset_sequences()
    print(f"\n导入完成！共导入 {total_rows} 行数据到 PostgreSQL")
    print("建议验证: 比较 JSON 文件行数与 PostgreSQL 表行数")


if __name__ == "__main__":
    asyncio.run(main())
