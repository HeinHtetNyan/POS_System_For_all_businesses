"""backfill_notification_entity_ids

Revision ID: e7a4c1f92d68
Revises: d3f8a92b6c17
Create Date: 2026-07-05 00:00:00.000000

Backfills purchase_order_id / goods_receipt_id into the metadata of existing
PROCUREMENT notifications created before those keys were added to the
publish payload. Without this, notifications created before the fix never
show a "View Purchase Order" / "View Goods Receipt" link on the detail page,
even though the underlying PO/receipt still exists and can be resolved by
the po_number/receipt_number already stored in metadata.

Note: this cannot recover tenant_id for old platform-level (Super Admin)
subscription notifications — that value was never stored anywhere on the
notification itself, so there's nothing to backfill it from. Only new
platform notifications going forward will carry it.
"""
from __future__ import annotations

from alembic import op

# revision identifiers, used by Alembic.
revision = "e7a4c1f92d68"
down_revision = "d3f8a92b6c17"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Purchase Order notifications ("... Needs Approval" / "... Approved")
    op.execute(
        """
        UPDATE notifications n
        SET metadata = n.metadata || jsonb_build_object('purchase_order_id', po.id::text)
        FROM purchase_orders po
        WHERE n.type = 'PROCUREMENT'
          AND n.tenant_id = po.tenant_id
          AND n.metadata ? 'po_number'
          AND n.metadata->>'po_number' = po.po_number
          AND NOT (n.metadata ? 'purchase_order_id')
        """
    )

    # Goods Receipt notifications ("Goods Receipt ... Created")
    op.execute(
        """
        UPDATE notifications n
        SET metadata = n.metadata || jsonb_build_object(
            'goods_receipt_id', gr.id::text,
            'purchase_order_id', gr.purchase_order_id::text
        )
        FROM goods_receipts gr
        WHERE n.type = 'PROCUREMENT'
          AND n.tenant_id = gr.tenant_id
          AND n.metadata ? 'receipt_number'
          AND n.metadata->>'receipt_number' = gr.receipt_number
          AND NOT (n.metadata ? 'goods_receipt_id')
        """
    )


def downgrade() -> None:
    # Backfilled keys are additive and harmless to leave — not worth
    # reconstructing which rows were touched to strip them back out.
    pass
