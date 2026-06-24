"""Fix entitlement codes: rename max_* to canonical codes and merge branch heads

Revision ID: s4t5u6v7w8
Revises: g2h5k8m1n3p6, r3s4t5u6v7
Create Date: 2026-05-30

Changes:
  - Merges the two branch heads (g2h5k8m1n3p6 and r3s4t5u6v7) into a single head
  - Renames any plan_entitlements and tenant_entitlement_overrides rows that used
    the old max_* codes to the canonical codes enforced by the backend gates:
      max_products -> products
      max_branches -> branches
      max_users    -> users
      max_customers -> customers (already canonical, included for safety)
      max_devices  -> devices   (already canonical, included for safety)
"""
from __future__ import annotations

from alembic import op

revision = "s4t5u6v7w8"
down_revision = ("g2h5k8m1n3p6", "r3s4t5u6v7")
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Rename stale max_* feature_code values in plan_entitlements
    # Use ON CONFLICT DO NOTHING so that if the canonical row already exists
    # we simply delete the stale duplicate instead of erroring.
    for old_code, new_code in [
        ("max_products", "products"),
        ("max_branches", "branches"),
        ("max_users", "users"),
        ("max_customers", "customers"),
        ("max_devices", "devices"),
    ]:
        # Attempt update; rows that would collide with an existing canonical row
        # are skipped (updated to a temp sentinel that we then delete).
        op.execute(f"""
            UPDATE plan_entitlements
            SET feature_code = '{new_code}',
                updated_at   = now()
            WHERE feature_code = '{old_code}'
              AND NOT EXISTS (
                  SELECT 1 FROM plan_entitlements other
                  WHERE other.plan_id      = plan_entitlements.plan_id
                    AND other.feature_code = '{new_code}'
              )
        """)
        # Delete any remaining stale rows (duplicates that couldn't be renamed)
        op.execute(f"""
            DELETE FROM plan_entitlements
            WHERE feature_code = '{old_code}'
        """)

    # Same for tenant_entitlement_overrides
    for old_code, new_code in [
        ("max_products", "products"),
        ("max_branches", "branches"),
        ("max_users", "users"),
        ("max_customers", "customers"),
        ("max_devices", "devices"),
    ]:
        op.execute(f"""
            UPDATE tenant_entitlement_overrides
            SET feature_code = '{new_code}',
                updated_at   = now()
            WHERE feature_code = '{old_code}'
              AND NOT EXISTS (
                  SELECT 1 FROM tenant_entitlement_overrides other
                  WHERE other.tenant_id    = tenant_entitlement_overrides.tenant_id
                    AND other.feature_code = '{new_code}'
              )
        """)
        op.execute(f"""
            DELETE FROM tenant_entitlement_overrides
            WHERE feature_code = '{old_code}'
        """)


def downgrade() -> None:
    # Reverse: rename canonical codes back to max_* codes.
    # NOTE: This is a best-effort rollback. Any rows that were deleted as
    # duplicates during upgrade cannot be recovered.
    for new_code, old_code in [
        ("products", "max_products"),
        ("branches", "max_branches"),
        ("users", "max_users"),
    ]:
        op.execute(f"""
            UPDATE plan_entitlements
            SET feature_code = '{old_code}',
                updated_at   = now()
            WHERE feature_code = '{new_code}'
              AND NOT EXISTS (
                  SELECT 1 FROM plan_entitlements other
                  WHERE other.plan_id      = plan_entitlements.plan_id
                    AND other.feature_code = '{old_code}'
              )
        """)
        op.execute(f"""
            UPDATE tenant_entitlement_overrides
            SET feature_code = '{old_code}',
                updated_at   = now()
            WHERE feature_code = '{new_code}'
              AND NOT EXISTS (
                  SELECT 1 FROM tenant_entitlement_overrides other
                  WHERE other.tenant_id    = tenant_entitlement_overrides.tenant_id
                    AND other.feature_code = '{old_code}'
              )
        """)
