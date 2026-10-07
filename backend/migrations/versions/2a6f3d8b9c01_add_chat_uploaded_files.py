"""add chat uploaded files

Revision ID: 2a6f3d8b9c01
Revises: 9b7d4c2f6a18
Create Date: 2026-09-05 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "2a6f3d8b9c01"
down_revision: Union[str, None] = "9b7d4c2f6a18"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _get_inspector():
    return sa.inspect(op.get_bind())


def _has_table(table_name: str) -> bool:
    return table_name in _get_inspector().get_table_names()


def upgrade() -> None:
    if not _has_table("users"):
        return

    if _has_table("chat_uploaded_files"):
        return

    op.create_table(
        "chat_uploaded_files",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("file_id", sa.String(length=128), nullable=False),
        sa.Column("file_name", sa.String(length=255), nullable=False),
        sa.Column("content_type", sa.String(length=100), nullable=True),
        sa.Column("size", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_chat_uploaded_files_id"),
        "chat_uploaded_files",
        ["id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_chat_uploaded_files_user_id"),
        "chat_uploaded_files",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_chat_uploaded_files_file_id"),
        "chat_uploaded_files",
        ["file_id"],
        unique=True,
    )


def downgrade() -> None:
    if not _has_table("chat_uploaded_files"):
        return

    op.drop_index(op.f("ix_chat_uploaded_files_file_id"), table_name="chat_uploaded_files")
    op.drop_index(op.f("ix_chat_uploaded_files_user_id"), table_name="chat_uploaded_files")
    op.drop_index(op.f("ix_chat_uploaded_files_id"), table_name="chat_uploaded_files")
    op.drop_table("chat_uploaded_files")
