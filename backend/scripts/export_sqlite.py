"""
SQLite → JSON 数据导出脚本

从 medical_consultation.db 中导出 7 张表的数据为 JSON 文件，
保持加密字段原样（不解密），供后续导入 PostgreSQL 使用。

用法: python scripts/export_sqlite.py
"""
import json
import os
import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parent.parent / "medical_consultation.db"
OUTPUT_DIR = Path(__file__).resolve().parent / "exported_data"

# 导出顺序遵循外键依赖：先导出被引用的表
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


def export_table(conn: sqlite3.Connection, table: str, output_dir: Path) -> int:
    """导出单张表到 JSON 文件，返回导出的行数。"""
    cursor = conn.execute(f"SELECT * FROM {table}")
    columns = [desc[0] for desc in cursor.description]
    rows = []
    for row in cursor.fetchall():
        rows.append(dict(zip(columns, row)))

    output_path = output_dir / f"{table}.json"
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2, default=str)

    return len(rows)


def main():
    if not DB_PATH.exists():
        print(f"错误: 找不到 SQLite 数据库文件: {DB_PATH}")
        print("请在项目根目录运行此脚本：python scripts/export_sqlite.py")
        return

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row

    total_rows = 0
    for table in TABLES:
        try:
            count = export_table(conn, table, OUTPUT_DIR)
            total_rows += count
            print(f"  ✓ {table}: {count} 行")
        except sqlite3.OperationalError as e:
            print(f"  ⚠ {table}: 跳过 ({e})")

    conn.close()

    print(f"\n导出完成！共导出 {total_rows} 行数据到 {OUTPUT_DIR}/")
    print(f"下一步：运行 python scripts/import_to_pg.py 将数据导入 PostgreSQL")


if __name__ == "__main__":
    main()
