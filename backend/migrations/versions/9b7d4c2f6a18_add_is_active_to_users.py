"""add is_active to users

Revision ID: 9b7d4c2f6a18
Revises: c44159d0aecb
Create Date: 2026-09-02 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "9b7d4c2f6a18"
down_revision: Union[str, None] = "c44159d0aecb"
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


def upgrade() -> None:
    if not _has_table("users"):
        return

    if not _has_column("users", "is_active"):
        op.add_column(
            "users",
            sa.Column(
                "is_active",
                sa.Boolean(),
                nullable=True,
                server_default=sa.true(),
            ),
        )

    dialect = op.get_bind().dialect.name
    true_literal = "TRUE" if dialect == "postgresql" else "1"
    op.execute(
        sa.text(
            f"UPDATE users SET is_active = {true_literal} "
            "WHERE is_active IS NULL"
        )
    )


def downgrade() -> None:
    if not _has_table("users"):
        return

    if _has_column("users", "is_active"):
        op.drop_column("users", "is_active")
