"""Seed REFERRAL_TRIAL subscription plan and its entitlements

Revision ID: u2v3w4x5y6z7
Revises: t1u2v3w4x5y6
Create Date: 2026-05-30

Changes:
  - Inserts the REFERRAL_TRIAL plan (price=0, trial_days=30, is_referral_plan=True,
    is_trial=True, is_public=False).
  - Seeds 6 plan_entitlements for REFERRAL_TRIAL (slightly better than FREE):
      branches:    enabled=True,  limit=2
      users:       enabled=True,  limit=5
      products:    enabled=True,  limit=100
      customers:   enabled=True,  limit=200
      analytics:   enabled=False, limit=NULL
      procurement: enabled=False, limit=NULL
  - All inserts use ON CONFLICT DO NOTHING so the migration is safe to re-run.
"""
from __future__ import annotations

from alembic import op

revision = "u2v3w4x5y6z7"
down_revision = "t1u2v3w4x5y6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Insert the REFERRAL_TRIAL plan (idempotent)
    op.execute("""
        INSERT INTO subscription_plans
            (id, name, code, description, billing_cycle, price, currency,
             trial_days, is_active, is_trial, is_referral_plan, is_public,
             sort_order, created_at, updated_at)
        VALUES (
            gen_random_uuid(),
            'Referral Trial',
            'REFERRAL_TRIAL',
            'Extended trial plan for tenants who sign up via a reseller referral code.',
            'MONTHLY',
            0,
            'MMK',
            30,
            true,
            true,
            true,
            false,
            1,
            now(),
            now()
        )
        ON CONFLICT (code) DO NOTHING
    """)

    # 2. Seed entitlements for REFERRAL_TRIAL (slightly better than FREE)
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
                ('branches',    true,  2),
                ('users',       true,  5),
                ('products',    true,  100),
                ('customers',   true,  200),
                ('analytics',   false, NULL::int),
                ('procurement', false, NULL::int)
        ) AS e(feature_code, enabled, limit_value)
        WHERE sp.code = 'REFERRAL_TRIAL'
        ON CONFLICT (plan_id, feature_code) DO NOTHING
    """)


def downgrade() -> None:
    # Remove entitlements first (FK constraint), then the plan.
    # Only safe if no tenants are actively subscribed to this plan.
    # If tenants are subscribed, the DELETE on subscription_plans will fail
    # due to the RESTRICT foreign key on tenant_subscriptions.plan_id —
    # that is intentional: do not downgrade while tenants are on this plan.
    op.execute("""
        DELETE FROM plan_entitlements
        WHERE plan_id = (
            SELECT id FROM subscription_plans WHERE code = 'REFERRAL_TRIAL'
        )
    """)
    op.execute("""
        DELETE FROM subscription_plans
        WHERE code = 'REFERRAL_TRIAL'
          AND NOT EXISTS (
              SELECT 1 FROM tenant_subscriptions ts
              WHERE ts.plan_id = (
                  SELECT id FROM subscription_plans sp2 WHERE sp2.code = 'REFERRAL_TRIAL'
              )
          )
    """)
