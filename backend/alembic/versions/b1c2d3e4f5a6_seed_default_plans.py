"""Seed 6 default subscription plans

Revision ID: b1c2d3e4f5a6
Revises: z7a8b9c0d1e2
Create Date: 2026-06-26

Inserts 6 hardcoded default plans (Starter, Basic, Standard, Professional, Business, Enterprise)
with their entitlements if they don't already exist. Fully idempotent via ON CONFLICT DO NOTHING.
"""
from __future__ import annotations

from alembic import op

revision = "b1c2d3e4f5a6"
down_revision = "z7a8b9c0d1e2"
branch_labels = None
depends_on = None

_PLANS = [
    # (code, name, description, price, sort_order, is_custom)
    ("STARTER",      "Starter",      "Perfect for small shops getting started.",                    29000, 1, False),
    ("BASIC",        "Basic",        "For growing businesses that need analytics.",                 49000, 2, False),
    ("STANDARD",     "Standard",     "Multi-branch support with procurement tools.",                79000, 3, False),
    ("PROFESSIONAL", "Professional", "Full feature access for established businesses.",            129000, 4, False),
    ("BUSINESS",     "Business",     "Unlimited scale for high-volume operations.",                199000, 5, False),
    ("ENTERPRISE",   "Enterprise",   "Tailored pricing and unlimited everything. Contact us.",          0, 6, True),
]

# (code, feature_code, enabled, limit_value)
_ENTITLEMENTS: list[tuple[str, str, bool, int | None]] = [
    # Starter
    ("STARTER", "pos",              True,  None),
    ("STARTER", "inventory",        True,  None),
    ("STARTER", "analytics",        False, None),
    ("STARTER", "advanced_reports", False, None),
    ("STARTER", "procurement",      False, None),
    ("STARTER", "products",         True,  200),
    ("STARTER", "branches",         True,  1),
    ("STARTER", "users",            True,  5),
    ("STARTER", "customers",        True,  500),
    ("STARTER", "devices",          True,  2),
    # Basic
    ("BASIC", "pos",              True,  None),
    ("BASIC", "inventory",        True,  None),
    ("BASIC", "analytics",        True,  None),
    ("BASIC", "advanced_reports", False, None),
    ("BASIC", "procurement",      False, None),
    ("BASIC", "products",         True,  500),
    ("BASIC", "branches",         True,  1),
    ("BASIC", "users",            True,  10),
    ("BASIC", "customers",        True,  1000),
    ("BASIC", "devices",          True,  3),
    # Standard
    ("STANDARD", "pos",              True,  None),
    ("STANDARD", "inventory",        True,  None),
    ("STANDARD", "analytics",        True,  None),
    ("STANDARD", "advanced_reports", False, None),
    ("STANDARD", "procurement",      True,  None),
    ("STANDARD", "products",         True,  2000),
    ("STANDARD", "branches",         True,  2),
    ("STANDARD", "users",            True,  20),
    ("STANDARD", "customers",        True,  5000),
    ("STANDARD", "devices",          True,  5),
    # Professional
    ("PROFESSIONAL", "pos",              True,  None),
    ("PROFESSIONAL", "inventory",        True,  None),
    ("PROFESSIONAL", "analytics",        True,  None),
    ("PROFESSIONAL", "advanced_reports", True,  None),
    ("PROFESSIONAL", "procurement",      True,  None),
    ("PROFESSIONAL", "products",         True,  None),
    ("PROFESSIONAL", "branches",         True,  5),
    ("PROFESSIONAL", "users",            True,  30),
    ("PROFESSIONAL", "customers",        True,  None),
    ("PROFESSIONAL", "devices",          True,  10),
    # Business
    ("BUSINESS", "pos",              True,  None),
    ("BUSINESS", "inventory",        True,  None),
    ("BUSINESS", "analytics",        True,  None),
    ("BUSINESS", "advanced_reports", True,  None),
    ("BUSINESS", "procurement",      True,  None),
    ("BUSINESS", "products",         True,  None),
    ("BUSINESS", "branches",         True,  10),
    ("BUSINESS", "users",            True,  None),
    ("BUSINESS", "customers",        True,  None),
    ("BUSINESS", "devices",          True,  None),
    # Enterprise
    ("ENTERPRISE", "pos",              True,  None),
    ("ENTERPRISE", "inventory",        True,  None),
    ("ENTERPRISE", "analytics",        True,  None),
    ("ENTERPRISE", "advanced_reports", True,  None),
    ("ENTERPRISE", "procurement",      True,  None),
    ("ENTERPRISE", "products",         True,  None),
    ("ENTERPRISE", "branches",         True,  None),
    ("ENTERPRISE", "users",            True,  None),
    ("ENTERPRISE", "customers",        True,  None),
    ("ENTERPRISE", "devices",          True,  None),
]


def upgrade() -> None:
    # Insert plans
    for code, name, description, price, sort_order, is_custom in _PLANS:
        op.execute(f"""
            INSERT INTO subscription_plans
                (id, name, code, description, billing_cycle, price, currency,
                 trial_days, is_active, is_trial, is_referral_plan, is_public,
                 is_custom, sort_order, created_at, updated_at)
            VALUES (
                gen_random_uuid(),
                '{name}',
                '{code}',
                '{description}',
                'MONTHLY',
                {price},
                'MMK',
                0,
                true,
                false,
                false,
                true,
                {'true' if is_custom else 'false'},
                {sort_order},
                now(),
                now()
            )
            ON CONFLICT (code) DO NOTHING
        """)

    # Insert entitlements
    for plan_code, feature_code, enabled, limit_value in _ENTITLEMENTS:
        limit_sql = "NULL" if limit_value is None else str(limit_value)
        op.execute(f"""
            INSERT INTO plan_entitlements
                (id, plan_id, feature_code, enabled, limit_value, created_at, updated_at)
            SELECT
                gen_random_uuid(),
                sp.id,
                '{feature_code}',
                {'true' if enabled else 'false'},
                {limit_sql},
                now(),
                now()
            FROM subscription_plans sp
            WHERE sp.code = '{plan_code}'
            ON CONFLICT (plan_id, feature_code) DO NOTHING
        """)


def downgrade() -> None:
    for plan_code, _, _, _ in _ENTITLEMENTS:
        op.execute(f"""
            DELETE FROM plan_entitlements
            WHERE plan_id = (SELECT id FROM subscription_plans WHERE code = '{plan_code}')
        """)

    for code, _, _, _, _, _ in _PLANS:
        op.execute(f"""
            DELETE FROM subscription_plans
            WHERE code = '{code}'
              AND NOT EXISTS (
                  SELECT 1 FROM tenant_subscriptions ts
                  WHERE ts.plan_id = (SELECT id FROM subscription_plans WHERE code = '{code}')
              )
        """)
