"""scope staff email uniqueness per tenant

Revision ID: c4d5e6f7a8b9
Revises: b3c4d5e6f7a8
Create Date: 2026-07-06

"""
from __future__ import annotations

from alembic import op

revision = "c4d5e6f7a8b9"
down_revision = "b3c4d5e6f7a8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_index("ix_users_email", table_name="users")
    op.create_index("ix_users_email", "users", ["email"], unique=False)

    # BUSINESS_OWNER/RESELLER/SUPER_ADMIN log in with plain email+password
    # (no business code), so their emails must stay globally unique.
    op.execute(
        """
        CREATE UNIQUE INDEX uq_users_email_global_non_staff
        ON users (email)
        WHERE role IN ('BUSINESS_OWNER', 'RESELLER', 'SUPER_ADMIN')
        """
    )
    # MANAGER/CASHIER/INVENTORY_STAFF only ever log in via business code +
    # phone — email is just an optional label, so two different businesses
    # may each use the same staff email without conflict.
    op.execute(
        """
        CREATE UNIQUE INDEX uq_users_email_per_tenant_staff
        ON users (tenant_id, email)
        WHERE role IN ('MANAGER', 'CASHIER', 'INVENTORY_STAFF')
        """
    )


def downgrade() -> None:
    op.drop_index("uq_users_email_per_tenant_staff", table_name="users")
    op.drop_index("uq_users_email_global_non_staff", table_name="users")

    op.drop_index("ix_users_email", table_name="users")
    op.create_index("ix_users_email", "users", ["email"], unique=True)
