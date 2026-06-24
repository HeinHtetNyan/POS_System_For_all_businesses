"""add platform_settings table for global payment methods

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-06-08
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = 'b2c3d4e5f6a7'
down_revision = 'a1b2c3d4e5f6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'platform_settings',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False, server_default=sa.text('gen_random_uuid()')),
        sa.Column('settings_key', sa.String(50), nullable=False),
        sa.Column('payment_methods', sa.JSON(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
        sa.PrimaryKeyConstraint('id', name='pk_platform_settings'),
        sa.UniqueConstraint('settings_key', name='uq_platform_settings_settings_key'),
    )
    op.create_index('ix_platform_settings_settings_key', 'platform_settings', ['settings_key'])


def downgrade() -> None:
    op.drop_index('ix_platform_settings_settings_key', table_name='platform_settings')
    op.drop_table('platform_settings')
