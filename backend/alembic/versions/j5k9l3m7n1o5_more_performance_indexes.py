"""more_performance_indexes

Revision ID: j5k9l3m7n1o5
Revises: c4d5e6f7a8b9
Create Date: 2026-07-06 00:00:00.000000

Follow-up to i4j8k2l6m9n3 (performance_indexes). That migration covered
orders/refunds/stock_movements/branch_inventory/customers/customer_ledger,
but several other tables have the same "filter by tenant_id, sort by
created_at" access pattern (via BaseRepository.get_all's default
`order_by(created_at.desc())`) and were left without a matching composite
index:

  products (tenant_id, created_at)               — ProductRepository.get_by_tenant
  categories (tenant_id, created_at)              — CategoryRepository.get_by_tenant
  brands (tenant_id, created_at)                  — BrandRepository.get_by_tenant
  suppliers (tenant_id, created_at)               — SupplierRepository.get_by_tenant
  users (tenant_id, created_at)                   — UserRepository.get_by_tenant / get_all_users
  audit_logs (tenant_id, created_at)              — AuditRepository.get_by_tenant
  audit_logs (tenant_id, action, created_at)      — AuditRepository.get_by_tenant (action filter)
  inventory_transfers (tenant_id, created_at)     — InventoryTransferRepository.get_by_tenant_with_items
  inventory_adjustments (tenant_id, created_at)   — InventoryAdjustmentRepository.get_by_tenant_with_items

`branches` has the same shape but tenant row counts are small (dozens at
most), so a composite index there wouldn't pay for itself — skipped.
"""
from __future__ import annotations

from typing import Sequence, Union

from alembic import op

revision: str = "j5k9l3m7n1o5"
down_revision: Union[str, None] = "c4d5e6f7a8b9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_index(
        "ix_products_tenant_created_at",
        "products",
        ["tenant_id", "created_at"],
    )
    op.create_index(
        "ix_categories_tenant_created_at",
        "categories",
        ["tenant_id", "created_at"],
    )
    op.create_index(
        "ix_brands_tenant_created_at",
        "brands",
        ["tenant_id", "created_at"],
    )
    op.create_index(
        "ix_suppliers_tenant_created_at",
        "suppliers",
        ["tenant_id", "created_at"],
    )
    op.create_index(
        "ix_users_tenant_created_at",
        "users",
        ["tenant_id", "created_at"],
    )
    op.create_index(
        "ix_audit_logs_tenant_created_at",
        "audit_logs",
        ["tenant_id", "created_at"],
    )
    op.create_index(
        "ix_audit_logs_tenant_action_created_at",
        "audit_logs",
        ["tenant_id", "action", "created_at"],
    )
    op.create_index(
        "ix_inv_transfer_tenant_created_at",
        "inventory_transfers",
        ["tenant_id", "created_at"],
    )
    op.create_index(
        "ix_inv_adj_tenant_created_at",
        "inventory_adjustments",
        ["tenant_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_inv_adj_tenant_created_at", table_name="inventory_adjustments")
    op.drop_index("ix_inv_transfer_tenant_created_at", table_name="inventory_transfers")
    op.drop_index("ix_audit_logs_tenant_action_created_at", table_name="audit_logs")
    op.drop_index("ix_audit_logs_tenant_created_at", table_name="audit_logs")
    op.drop_index("ix_users_tenant_created_at", table_name="users")
    op.drop_index("ix_suppliers_tenant_created_at", table_name="suppliers")
    op.drop_index("ix_brands_tenant_created_at", table_name="brands")
    op.drop_index("ix_categories_tenant_created_at", table_name="categories")
    op.drop_index("ix_products_tenant_created_at", table_name="products")
