"""order_idempotency_key

Revision ID: 4b45e3ddb484
Revises: 8e678037b59a
Create Date: 2026-07-04 00:00:00.000000

Adds a nullable, per-tenant-unique idempotency_key to orders so a retried
checkout submission (e.g. an offline POS device replaying its sync queue
after a network drop) can be recognized and returned as the original order
instead of creating a duplicate sale.
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "4b45e3ddb484"
down_revision: Union[str, None] = "8e678037b59a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("orders", sa.Column("idempotency_key", sa.String(100), nullable=True))
    op.create_index(
        "uq_orders_tenant_idempotency_key",
        "orders",
        ["tenant_id", "idempotency_key"],
        unique=True,
        postgresql_where=sa.text("idempotency_key IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index("uq_orders_tenant_idempotency_key", table_name="orders")
    op.drop_column("orders", "idempotency_key")
