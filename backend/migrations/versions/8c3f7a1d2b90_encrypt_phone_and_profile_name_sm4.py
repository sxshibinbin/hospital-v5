"""encrypt phone and profile name with sm4

Revision ID: 8c3f7a1d2b90
Revises: 7d8e9f0a1b2c
Create Date: 2026-09-05 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

from db_encryption import (
    decrypt_sensitive_value,
    encrypt_sensitive_value,
    is_encrypted_sensitive_value,
    phone_lookup_hash,
)


revision: str = "8c3f7a1d2b90"
down_revision: Union[str, None] = "7d8e9f0a1b2c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _get_inspector():
    return sa.inspect(op.get_bind())


def _has_table(table_name: str) -> bool:
    return table_name in _get_inspector().get_table_names()


def _has_column(table_name: str, column_name: str) -> bool:
    inspector = _get_inspector()
    return column_name in {
        column["name"] for column in inspector.get_columns(table_name)
    }


def _has_index(table_name: str, index_name: str) -> bool:
    inspector = _get_inspector()
    return index_name in {
        index["name"] for index in inspector.get_indexes(table_name)
    }


def _alter_sensitive_columns_to_text() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        return

    if _has_table("users") and _has_column("users", "phone"):
        op.alter_column(
            "users",
            "phone",
            existing_type=sa.String(length=20),
            type_=sa.Text(),
            existing_nullable=False,
        )
    if _has_table("patient_profiles") and _has_column("patient_profiles", "name"):
        op.alter_column(
            "patient_profiles",
            "name",
            existing_type=sa.String(length=50),
            type_=sa.Text(),
            existing_nullable=False,
        )


def _alter_sensitive_columns_to_string() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        return

    if _has_table("users") and _has_column("users", "phone"):
        op.alter_column(
            "users",
            "phone",
            existing_type=sa.Text(),
            type_=sa.String(length=20),
            existing_nullable=False,
        )
    if _has_table("patient_profiles") and _has_column("patient_profiles", "name"):
        op.alter_column(
            "patient_profiles",
            "name",
            existing_type=sa.Text(),
            type_=sa.String(length=50),
            existing_nullable=False,
        )


def _encrypt_user_phones() -> None:
    if not _has_table("users") or not _has_column("users", "phone"):
        return
    if not _has_column("users", "phone_hash"):
        return

    bind = op.get_bind()
    rows = bind.execute(
        sa.text("SELECT id, phone, phone_hash FROM users ORDER BY id")
    ).mappings().all()
    assigned_phone_hashes = {
        row["phone_hash"]: row["id"]
        for row in rows
        if row["phone_hash"]
    }
    for row in rows:
        plain_phone = decrypt_sensitive_value(row["phone"])
        if not plain_phone:
            continue

        encrypted_phone = (
            row["phone"]
            if is_encrypted_sensitive_value(row["phone"])
            else encrypt_sensitive_value(plain_phone)
        )
        lookup_hash = phone_lookup_hash(plain_phone)
        hash_owner_id = assigned_phone_hashes.get(lookup_hash)
        next_phone_hash = lookup_hash
        if hash_owner_id is not None and hash_owner_id != row["id"]:
            next_phone_hash = row["phone_hash"]
        else:
            assigned_phone_hashes[lookup_hash] = row["id"]

        if row["phone"] == encrypted_phone and row["phone_hash"] == next_phone_hash:
            continue

        bind.execute(
            sa.text(
                "UPDATE users "
                "SET phone = :phone, phone_hash = :phone_hash "
                "WHERE id = :id"
            ),
            {"id": row["id"], "phone": encrypted_phone, "phone_hash": next_phone_hash},
        )


def _encrypt_profile_names() -> None:
    if not _has_table("patient_profiles") or not _has_column("patient_profiles", "name"):
        return

    bind = op.get_bind()
    rows = bind.execute(sa.text("SELECT id, name FROM patient_profiles")).mappings().all()
    for row in rows:
        plain_name = decrypt_sensitive_value(row["name"])
        if not plain_name:
            continue

        encrypted_name = (
            row["name"]
            if is_encrypted_sensitive_value(row["name"])
            else encrypt_sensitive_value(plain_name)
        )
        if row["name"] == encrypted_name:
            continue

        bind.execute(
            sa.text("UPDATE patient_profiles SET name = :name WHERE id = :id"),
            {"id": row["id"], "name": encrypted_name},
        )


def _decrypt_user_phones() -> None:
    if not _has_table("users") or not _has_column("users", "phone"):
        return

    bind = op.get_bind()
    rows = bind.execute(sa.text("SELECT id, phone FROM users")).mappings().all()
    for row in rows:
        plain_phone = decrypt_sensitive_value(row["phone"])
        if plain_phone and plain_phone != row["phone"]:
            bind.execute(
                sa.text("UPDATE users SET phone = :phone WHERE id = :id"),
                {"id": row["id"], "phone": plain_phone},
            )


def _decrypt_profile_names() -> None:
    if not _has_table("patient_profiles") or not _has_column("patient_profiles", "name"):
        return

    bind = op.get_bind()
    rows = bind.execute(sa.text("SELECT id, name FROM patient_profiles")).mappings().all()
    for row in rows:
        plain_name = decrypt_sensitive_value(row["name"])
        if plain_name and plain_name != row["name"]:
            bind.execute(
                sa.text("UPDATE patient_profiles SET name = :name WHERE id = :id"),
                {"id": row["id"], "name": plain_name},
            )


def upgrade() -> None:
    if not _has_table("users"):
        return

    if not _has_column("users", "phone_hash"):
        op.add_column("users", sa.Column("phone_hash", sa.String(length=64), nullable=True))

    _alter_sensitive_columns_to_text()
    _encrypt_user_phones()
    _encrypt_profile_names()

    duplicate_count = op.get_bind().execute(
        sa.text(
            "SELECT COUNT(*) FROM ("
            "SELECT phone_hash FROM users "
            "WHERE phone_hash IS NOT NULL "
            "GROUP BY phone_hash HAVING COUNT(*) > 1"
            ") duplicated_phone_hashes"
        )
    ).scalar()
    if duplicate_count:
        return

    if not _has_index("users", "ix_users_phone_hash"):
        op.create_index("ix_users_phone_hash", "users", ["phone_hash"], unique=True)


def downgrade() -> None:
    _decrypt_user_phones()
    _decrypt_profile_names()

    if _has_table("users") and _has_index("users", "ix_users_phone_hash"):
        op.drop_index("ix_users_phone_hash", table_name="users")
    if _has_table("users") and _has_column("users", "phone_hash"):
        op.drop_column("users", "phone_hash")

    _alter_sensitive_columns_to_string()
