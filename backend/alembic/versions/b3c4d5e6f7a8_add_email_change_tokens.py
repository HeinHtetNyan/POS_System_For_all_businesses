"""add email_change_tokens table

Revision ID: b3c4d5e6f7a8
Revises: a9b8c7d6e5f4
Create Date: 2026-07-06

"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "b3c4d5e6f7a8"
down_revision = "a9b8c7d6e5f4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "email_change_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("new_email", sa.String(255), nullable=False),
        sa.Column("token_hash", sa.String(255), nullable=False, unique=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("is_used", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_email_change_tokens_user_id", "email_change_tokens", ["user_id"])
    op.create_index("ix_email_change_tokens_token_hash", "email_change_tokens", ["token_hash"], unique=True)


def downgrade() -> None:
    op.drop_index("ix_email_change_tokens_token_hash", table_name="email_change_tokens")
    op.drop_index("ix_email_change_tokens_user_id", table_name="email_change_tokens")
    op.drop_table("email_change_tokens")
