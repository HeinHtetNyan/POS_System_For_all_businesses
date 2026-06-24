"""Introduce Free plan as default: rename BASIC→FREE, deactivate old trial plan, backfill tenants

Revision ID: r3s4t5u6v7
Revises: q2s3t4u5v6
Create Date: 2026-05-29

Changes:
  - tenant_subscriptions.expires_at becomes nullable (Free plan never expires)
  - Existing TRIAL plan (is_trial=true) stripped of trial role
  - BASIC plan renamed to FREE and promoted to is_trial=true
  - Free plan entitlements seeded (branches:1, users:3, products:50, customers:100,
    analytics:disabled, procurement:disabled)
  - All tenants without a subscription get a Free ACTIVE subscription
  - Those tenants' status is set to ACTIVE if still TRIAL
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

revision = "r3s4t5u6v7"
down_revision = "q2s3t4u5v6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Make expires_at nullable (Free plan has no expiry)
    op.alter_column(
        "tenant_subscriptions",
        "expires_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=True,
    )

    # 2. Strip trial-plan role from every existing is_trial plan
    op.execute("UPDATE subscription_plans SET is_trial = false WHERE is_trial = true")

    # 3. Promote the BASIC (Free) plan to the canonical Free plan
    #   Rename code BASIC → FREE, ensure price=0, trial_days=0, is_trial=true.
    #   Keep is_public=false so it doesn't appear in the public upgrade list.
    op.execute("""
        UPDATE subscription_plans
        SET
            code        = 'FREE',
            name        = 'Free',
            description = 'Free plan with basic features. Upgrade anytime.',
            price       = 0,
            trial_days  = 0,
            is_trial    = true,
            is_active   = true,
            is_public   = false,
            sort_order  = 0,
            updated_at  = now()
        WHERE code = 'BASIC'
    """)

    # 4. Seed entitlements for the Free plan (idempotent)
    op.execute("""
        INSERT INTO plan_entitlements
            (id, plan_id, feature_code, enabled, limit_value, created_at, updated_at)
        SELECT
            gen_random_uuid(),
            sp.id,
            e.feature_code,
            e.enabled,
            e.limit_value,
            now(),
            now()
        FROM subscription_plans sp
        CROSS JOIN (
            VALUES
                ('branches',    true,  1),
                ('users',       true,  3),
                ('products',    true,  50),
                ('customers',   true,  100),
                ('analytics',   false, NULL::int),
                ('procurement', false, NULL::int)
        ) AS e(feature_code, enabled, limit_value)
        WHERE sp.code = 'FREE'
        ON CONFLICT (plan_id, feature_code) DO UPDATE
            SET enabled     = EXCLUDED.enabled,
                limit_value = EXCLUDED.limit_value,
                updated_at  = now()
    """)

    # 5. Backfill tenants that have no subscription → Free / ACTIVE
    op.execute("""
        INSERT INTO tenant_subscriptions
            (id, tenant_id, plan_id, status, started_at, expires_at,
             trial_ends_at, auto_renew, created_at, updated_at)
        SELECT
            gen_random_uuid(),
            t.id,
            sp.id,
            'ACTIVE',
            now(),
            NULL,
            NULL,
            true,
            now(),
            now()
        FROM tenants t
        CROSS JOIN subscription_plans sp
        WHERE sp.code = 'FREE'
          AND t.is_deleted = false
          AND NOT EXISTS (
              SELECT 1 FROM tenant_subscriptions ts WHERE ts.tenant_id = t.id
          )
    """)

    # 6. Fix denormalised subscription_plan code on tenants
    #   Tenants that previously stored 'BASIC' now store 'FREE'.
    op.execute("""
        UPDATE tenants
        SET subscription_plan = 'FREE',
            updated_at        = now()
        WHERE subscription_plan = 'BASIC'
    """)

    # 7. Mark those newly-backfilled tenants as ACTIVE
    op.execute("""
        UPDATE tenants t
        SET status     = 'ACTIVE',
            updated_at = now()
        WHERE t.is_deleted = false
          AND t.status     = 'TRIAL'
          AND EXISTS (
              SELECT 1
              FROM tenant_subscriptions ts
              JOIN subscription_plans sp ON ts.plan_id = sp.id
              WHERE ts.tenant_id = t.id
                AND sp.code      = 'FREE'
                AND ts.status    = 'ACTIVE'
          )
    """)


def downgrade() -> None:
    # Restore expires_at NOT NULL (set a far-future date for any NULL rows)
    op.execute(
        "UPDATE tenant_subscriptions "
        "SET expires_at = now() + INTERVAL '9999 days' "
        "WHERE expires_at IS NULL"
    )
    op.alter_column(
        "tenant_subscriptions",
        "expires_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=False,
    )

    # Revert plan rename (best-effort; data loss is acceptable on downgrade)
    op.execute("""
        UPDATE subscription_plans
        SET code = 'BASIC', name = 'Free', is_trial = false, updated_at = now()
        WHERE code = 'FREE'
    """)
    op.execute("""
        UPDATE subscription_plans
        SET is_trial = true, updated_at = now()
        WHERE code = 'TRIAL'
    """)
