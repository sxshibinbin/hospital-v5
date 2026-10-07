"""extend audit logs for operation logs

Revision ID: 7d8e9f0a1b2c
Revises: 2a6f3d8b9c01
Create Date: 2026-09-05 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "7d8e9f0a1b2c"
down_revision: Union[str, None] = "2a6f3d8b9c01"
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


def _has_foreign_key(table_name: str, fk_name: str) -> bool:
    inspector = _get_inspector()
    return fk_name in {
        foreign_key["name"] for foreign_key in inspector.get_foreign_keys(table_name)
    }


def _add_column_if_missing(column_name: str, column: sa.Column) -> None:
    if not _has_column("audit_logs", column_name):
        op.add_column("audit_logs", column)


def _create_index_if_missing(index_name: str, columns: list[str]) -> None:
    if not _has_index("audit_logs", index_name):
        op.create_index(index_name, "audit_logs", columns, unique=False)


def upgrade() -> None:
    if not _has_table("audit_logs"):
        return

    _add_column_if_missing("actor_user_id", sa.Column("actor_user_id", sa.Integer(), nullable=True))
    _add_column_if_missing("actor_type", sa.Column("actor_type", sa.String(length=20), nullable=True))
    _add_column_if_missing("actor_name", sa.Column("actor_name", sa.String(length=100), nullable=True))
    _add_column_if_missing("actor_phone_masked", sa.Column("actor_phone_masked", sa.String(length=20), nullable=True))
    _add_column_if_missing("terminal", sa.Column("terminal", sa.String(length=20), nullable=True))
    _add_column_if_missing("module", sa.Column("module", sa.String(length=50), nullable=True))
    _add_column_if_missing("result", sa.Column("result", sa.String(length=20), nullable=True))
    _add_column_if_missing("target_type", sa.Column("target_type", sa.String(length=50), nullable=True))
    _add_column_if_missing("ip_address", sa.Column("ip_address", sa.String(length=64), nullable=True))
    _add_column_if_missing("user_agent", sa.Column("user_agent", sa.String(length=300), nullable=True))
    _add_column_if_missing("request_id", sa.Column("request_id", sa.String(length=64), nullable=True))
    _add_column_if_missing("metadata_json", sa.Column("metadata_json", sa.Text(), nullable=True))

    _create_index_if_missing("ix_audit_logs_admin_id", ["admin_id"])
    _create_index_if_missing("ix_audit_logs_actor_user_id", ["actor_user_id"])
    _create_index_if_missing("ix_audit_logs_terminal", ["terminal"])
    _create_index_if_missing("ix_audit_logs_module", ["module"])
    _create_index_if_missing("ix_audit_logs_result", ["result"])
    _create_index_if_missing("ix_audit_logs_target_type", ["target_type"])
    _create_index_if_missing("ix_audit_logs_request_id", ["request_id"])

    if (
        op.get_bind().dialect.name != "sqlite"
        and _has_table("users")
        and not _has_foreign_key("audit_logs", "fk_audit_logs_actor_user_id_users")
    ):
        op.create_foreign_key(
            "fk_audit_logs_actor_user_id_users",
            "audit_logs",
            "users",
            ["actor_user_id"],
            ["id"],
        )


def downgrade() -> None:
    if not _has_table("audit_logs"):
        return

    if (
        op.get_bind().dialect.name != "sqlite"
        and _has_foreign_key("audit_logs", "fk_audit_logs_actor_user_id_users")
    ):
        op.drop_constraint(
            "fk_audit_logs_actor_user_id_users",
            "audit_logs",
            type_="foreignkey",
        )

    for index_name in [
        "ix_audit_logs_request_id",
        "ix_audit_logs_target_type",
        "ix_audit_logs_result",
        "ix_audit_logs_module",
        "ix_audit_logs_terminal",
        "ix_audit_logs_actor_user_id",
        "ix_audit_logs_admin_id",
    ]:
        if _has_index("audit_logs", index_name):
            op.drop_index(index_name, table_name="audit_logs")

    for column_name in [
        "metadata_json",
        "request_id",
        "user_agent",
        "ip_address",
        "target_type",
        "result",
        "module",
        "terminal",
        "actor_phone_masked",
        "actor_name",
        "actor_type",
        "actor_user_id",
    ]:
        if _has_column("audit_logs", column_name):
            op.drop_column("audit_logs", column_name)
