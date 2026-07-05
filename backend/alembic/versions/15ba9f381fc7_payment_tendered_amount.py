"""payment_tendered_amount

Revision ID: 15ba9f381fc7
Revises: 4b45e3ddb484
Create Date: 2026-07-04 00:00:00.000000

Adds a nullable tendered_amount to payments — the cash a customer actually
handed over, when it differs from the amount applied to the order. Without
this, "change due" shown to the cashier at checkout was computed client-side
but never sent to the backend, so it was always recorded as zero.
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "15ba9f381fc7"
down_revision: Union[str, None] = "4b45e3ddb484"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("payments", sa.Column("tendered_amount", sa.Numeric(12, 4), nullable=True))


def downgrade() -> None:
    op.drop_column("payments", "tendered_amount")
