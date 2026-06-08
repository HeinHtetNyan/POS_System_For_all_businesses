"""add payment_info to subscription_plans

Revision ID: a1b2c3d4e5f6
Revises: z7a8b9c0d1e2
Create Date: 2026-06-08
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = 'a1b2c3d4e5f6'
down_revision = 'z7a8b9c0d1e2'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'subscription_plans',
        sa.Column('payment_info', sa.JSON(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('subscription_plans', 'payment_info')
