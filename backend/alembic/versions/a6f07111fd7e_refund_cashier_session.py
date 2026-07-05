"""refund_cashier_session

Revision ID: a6f07111fd7e
Revises: e18f41005064
Create Date: 2026-07-04 00:00:00.000000

Adds a nullable cashier_session_id to refunds, snapshotting whichever
session was open when the refund was actually processed. Cash-session
reconciliation was previously attributing a refund's cash impact to the
session that made the ORIGINAL sale, not the session physically handing
the cash back — a refund processed in a different shift than the sale
would never be subtracted from any session's expected balance.
"""
from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "a6f07111fd7e"
down_revision: Union[str, None] = "e18f41005064"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("refunds", sa.Column("cashier_session_id", sa.UUID(), nullable=True))
    op.create_foreign_key(
        "fk_refunds_cashier_session_id",
        "refunds", "cashier_sessions",
        ["cashier_session_id"], ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_refunds_cashier_session_id", "refunds", type_="foreignkey")
    op.drop_column("refunds", "cashier_session_id")
