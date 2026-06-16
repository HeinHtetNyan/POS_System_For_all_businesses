"""payment_workflow_fields

Add action_type + target_plan_id to payment_proofs;
add pending_downgrade_plan_id + pending_downgrade_requested_at to tenant_subscriptions;
make proof_file_url nullable (system-generated proofs have no file yet).

Revision ID: t1u2v3w4x5y6
Revises: s4t5u6v7w8
Create Date: 2026-05-30

"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = "t1u2v3w4x5y6"
down_revision = "s4t5u6v7w8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Create the proof_action_type enum in the DB
    proof_action_type = sa.Enum(
        "INITIAL_ACTIVATION",
        "RENEWAL",
        "UPGRADE",
        name="proof_action_type",
    )
    proof_action_type.create(op.get_bind(), checkfirst=True)

    # 2. payment_proofs: add action_type column with safe default
    op.add_column(
        "payment_proofs",
        sa.Column(
            "action_type",
            sa.Enum(
                "INITIAL_ACTIVATION",
                "RENEWAL",
                "UPGRADE",
                name="proof_action_type",
                create_type=False,   # already created above
            ),
            nullable=False,
            server_default="INITIAL_ACTIVATION",
        ),
    )

    # 3. payment_proofs: add target_plan_id (nullable FK)
    op.add_column(
        "payment_proofs",
        sa.Column(
            "target_plan_id",
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.create_foreign_key(
        "fk_payment_proofs_target_plan_id",
        "payment_proofs",
        "subscription_plans",
        ["target_plan_id"],
        ["id"],
        ondelete="SET NULL",
    )

    # 4. payment_proofs: make proof_file_url nullable
    #    (system-generated pending proofs have no file path yet)
    op.alter_column(
        "payment_proofs",
        "proof_file_url",
        existing_type=sa.String(500),
        nullable=True,
    )

    # 5. tenant_subscriptions: add pending_downgrade_plan_id (nullable FK)
    op.add_column(
        "tenant_subscriptions",
        sa.Column(
            "pending_downgrade_plan_id",
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.create_foreign_key(
        "fk_tenant_subscriptions_pending_downgrade_plan_id",
        "tenant_subscriptions",
        "subscription_plans",
        ["pending_downgrade_plan_id"],
        ["id"],
        ondelete="SET NULL",
    )

    # 6. tenant_subscriptions: add pending_downgrade_requested_at
    op.add_column(
        "tenant_subscriptions",
        sa.Column(
            "pending_downgrade_requested_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )


def downgrade() -> None:
    # Reverse in opposite order
    op.drop_column("tenant_subscriptions", "pending_downgrade_requested_at")

    op.drop_constraint(
        "fk_tenant_subscriptions_pending_downgrade_plan_id",
        "tenant_subscriptions",
        type_="foreignkey",
    )
    op.drop_column("tenant_subscriptions", "pending_downgrade_plan_id")

    # Restore proof_file_url to NOT NULL (set empty string for any NULLs first)
    op.execute(
        "UPDATE payment_proofs SET proof_file_url = '' WHERE proof_file_url IS NULL"
    )
    op.alter_column(
        "payment_proofs",
        "proof_file_url",
        existing_type=sa.String(500),
        nullable=False,
    )

    op.drop_constraint(
        "fk_payment_proofs_target_plan_id",
        "payment_proofs",
        type_="foreignkey",
    )
    op.drop_column("payment_proofs", "target_plan_id")
    op.drop_column("payment_proofs", "action_type")

    # Drop the enum type
    sa.Enum(name="proof_action_type").drop(op.get_bind(), checkfirst=True)
