"""branch_inventory_cost_price

Revision ID: e18f41005064
Revises: 31b3bb6cd315
Create Date: 2026-07-04 00:00:00.000000

Adds a per-branch cost_price to branch_inventory. Cost was previously
tracked only on Product (tenant-wide), so receiving the same product at
different costs at two branches would overwrite the shared field and
corrupt COGS/valuation for whichever branch bought it at the earlier
price. Nullable — falls back to Product.cost_price until a branch
receives stock of its own.
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "e18f41005064"
down_revision: Union[str, None] = "31b3bb6cd315"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("branch_inventory", sa.Column("cost_price", sa.Numeric(12, 4), nullable=True))


def downgrade() -> None:
    op.drop_column("branch_inventory", "cost_price")
