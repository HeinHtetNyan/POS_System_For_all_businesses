"""add custom plan fields (is_custom, contact_links)

Revision ID: z7a8b9c0d1e2
Revises: y6z7a8b9c0d1
Create Date: 2026-06-06
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = 'z7a8b9c0d1e2'
down_revision = 'y6z7a8b9c0d1'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        'subscription_plans',
        sa.Column('is_custom', sa.Boolean(), nullable=False, server_default='false'),
    )
    op.add_column(
        'subscription_plans',
        sa.Column('contact_links', sa.JSON(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('subscription_plans', 'contact_links')
    op.drop_column('subscription_plans', 'is_custom')
