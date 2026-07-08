"""add app_download_links column to platform_settings

Revision ID: b85825339be2
Revises: n8o2p6q0r4s8
Create Date: 2026-07-09
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = 'b85825339be2'
down_revision = 'n8o2p6q0r4s8'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('platform_settings', sa.Column('app_download_links', sa.JSON(), nullable=True))


def downgrade() -> None:
    op.drop_column('platform_settings', 'app_download_links')
