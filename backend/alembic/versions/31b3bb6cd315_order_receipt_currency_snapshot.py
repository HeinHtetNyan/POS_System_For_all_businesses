"""order_receipt_currency_snapshot

Revision ID: 31b3bb6cd315
Revises: 15ba9f381fc7
Create Date: 2026-07-04 00:00:00.000000

Adds a nullable currency snapshot to orders and receipts. Currency was
previously never stored per-order — the frontend always displayed amounts
using the tenant's *current* currency setting, so changing a tenant's or
branch's currency later would retroactively repaint every historical
order/receipt. New rows get their branch's currency snapshotted at checkout
time; existing rows stay NULL since their historical currency can't be
recovered, and the frontend falls back to the tenant's current currency for
those.
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "31b3bb6cd315"
down_revision: Union[str, None] = "15ba9f381fc7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("orders", sa.Column("currency", sa.String(10), nullable=True))
    op.add_column("receipts", sa.Column("currency", sa.String(10), nullable=True))


def downgrade() -> None:
    op.drop_column("receipts", "currency")
    op.drop_column("orders", "currency")
