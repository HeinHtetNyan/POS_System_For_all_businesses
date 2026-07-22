"""raise reseller wallet min payout default to 50000 mmk

Revision ID: a2ade6f187c3
Revises: b85825339be2
Create Date: 2026-07-22 09:45:59.788328

"""
from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a2ade6f187c3'
down_revision: Union[str, None] = 'b85825339be2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "reseller_wallets",
        "min_payout_amount",
        server_default=sa.text("50000.000000"),
    )
    # Bring existing wallets still on the old default up to the new one.
    # Wallets an admin has already customized (any other value) are left alone.
    op.execute(
        "UPDATE reseller_wallets SET min_payout_amount = 50000.000000 "
        "WHERE min_payout_amount = 10000.000000"
    )


def downgrade() -> None:
    op.alter_column(
        "reseller_wallets",
        "min_payout_amount",
        server_default=sa.text("10000.000000"),
    )
    op.execute(
        "UPDATE reseller_wallets SET min_payout_amount = 10000.000000 "
        "WHERE min_payout_amount = 50000.000000"
    )
