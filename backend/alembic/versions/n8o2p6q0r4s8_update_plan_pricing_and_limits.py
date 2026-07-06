"""update_plan_pricing_and_limits

Revision ID: n8o2p6q0r4s8
Revises: k7l1m5n9o3p7
Create Date: 2026-07-07 02:20:00.000000

Repricing pass: new monthly prices for the paid tiers, new trial lengths for
Free/Referral Trial, and revised per-feature limits (products/branches/
staff/customers) across every plan. Values were already live-tested against
a local database; this migration is what carries them into production.

Also backfills the `advanced_reports`/`devices`/`inventory`/`pos`
entitlement rows that Free Trial and Referral Trial were missing entirely
(no row = treated as no access) — those two plans never got the full
feature set the other plans have had since launch.
"""
from __future__ import annotations

from alembic import op
from sqlalchemy import text

revision = 'n8o2p6q0r4s8'
down_revision = 'k7l1m5n9o3p7'
branch_labels = None
depends_on = None


PLAN_PRICING = [
    # code, price, trial_days
    ("FREE_TRIAL", 0, 30),
    ("REFERRAL_TRIAL", 0, 45),
    ("STARTER", 19000, 0),
    ("BASIC", 29000, 0),
    ("STANDARD", 49000, 0),
    ("PROFESSIONAL", 79000, 0),
    ("BUSINESS", 149000, 0),
]

ENTERPRISE_CONTACT_LINKS = (
    '{"phone": "+1 302 230-1026", "email": "dev@sawyuntech.com", '
    '"viber": "+66 817639774", "telegram": "+66 817639774", '
    '"facebook": "#", "tiktok": "#", "custom": []}'
)

# code, feature_code, enabled, limit_value (NULL = unlimited)
PLAN_ENTITLEMENTS = [
    ("FREE_TRIAL", "products", True, 150),
    ("FREE_TRIAL", "branches", True, 1),
    ("FREE_TRIAL", "users", True, 3),
    ("FREE_TRIAL", "customers", True, 50),
    ("FREE_TRIAL", "advanced_reports", True, None),
    ("FREE_TRIAL", "analytics", True, None),
    ("FREE_TRIAL", "devices", True, None),
    ("FREE_TRIAL", "inventory", True, None),
    ("FREE_TRIAL", "pos", True, None),
    ("FREE_TRIAL", "procurement", True, None),

    ("REFERRAL_TRIAL", "products", True, 250),
    ("REFERRAL_TRIAL", "branches", True, 1),
    ("REFERRAL_TRIAL", "users", True, 3),
    ("REFERRAL_TRIAL", "customers", True, 100),
    ("REFERRAL_TRIAL", "advanced_reports", True, None),
    ("REFERRAL_TRIAL", "analytics", True, None),
    ("REFERRAL_TRIAL", "devices", True, None),
    ("REFERRAL_TRIAL", "inventory", True, None),
    ("REFERRAL_TRIAL", "pos", True, None),
    ("REFERRAL_TRIAL", "procurement", True, None),

    ("STARTER", "products", True, 200),
    ("STARTER", "branches", True, 1),
    ("STARTER", "users", True, 3),
    ("STARTER", "customers", True, 75),
    ("STARTER", "advanced_reports", True, None),
    ("STARTER", "analytics", True, None),
    ("STARTER", "devices", True, None),
    ("STARTER", "inventory", True, None),
    ("STARTER", "pos", True, None),
    ("STARTER", "procurement", True, None),

    ("BASIC", "products", True, 350),
    ("BASIC", "branches", True, 1),
    ("BASIC", "users", True, 5),
    ("BASIC", "customers", True, 150),
    ("BASIC", "advanced_reports", True, None),
    ("BASIC", "analytics", True, None),
    ("BASIC", "devices", True, None),
    ("BASIC", "inventory", True, None),
    ("BASIC", "pos", True, None),
    ("BASIC", "procurement", True, None),

    ("STANDARD", "products", True, 600),
    ("STANDARD", "branches", True, 2),
    ("STANDARD", "users", True, 10),
    ("STANDARD", "customers", True, 500),
    ("STANDARD", "advanced_reports", True, None),
    ("STANDARD", "analytics", True, None),
    ("STANDARD", "devices", True, None),
    ("STANDARD", "inventory", True, None),
    ("STANDARD", "pos", True, None),
    ("STANDARD", "procurement", True, None),

    ("PROFESSIONAL", "products", True, 1200),
    ("PROFESSIONAL", "branches", True, 5),
    ("PROFESSIONAL", "users", True, 30),
    ("PROFESSIONAL", "customers", True, 1500),
    ("PROFESSIONAL", "advanced_reports", True, None),
    ("PROFESSIONAL", "analytics", True, None),
    ("PROFESSIONAL", "devices", True, None),
    ("PROFESSIONAL", "inventory", True, None),
    ("PROFESSIONAL", "pos", True, None),
    ("PROFESSIONAL", "procurement", True, None),

    ("BUSINESS", "products", True, 3000),
    ("BUSINESS", "branches", True, 10),
    ("BUSINESS", "users", True, 100),
    ("BUSINESS", "customers", True, 5000),
    ("BUSINESS", "advanced_reports", True, None),
    ("BUSINESS", "analytics", True, None),
    ("BUSINESS", "devices", True, None),
    ("BUSINESS", "inventory", True, None),
    ("BUSINESS", "pos", True, None),
    ("BUSINESS", "procurement", True, None),

    ("ENTERPRISE", "products", True, None),
    ("ENTERPRISE", "branches", True, None),
    ("ENTERPRISE", "users", True, None),
    ("ENTERPRISE", "customers", True, None),
    ("ENTERPRISE", "advanced_reports", True, None),
    ("ENTERPRISE", "analytics", True, None),
    ("ENTERPRISE", "devices", True, None),
    ("ENTERPRISE", "inventory", True, None),
    ("ENTERPRISE", "pos", True, None),
    ("ENTERPRISE", "procurement", True, None),
]


def upgrade() -> None:
    conn = op.get_bind()

    for code, price, trial_days in PLAN_PRICING:
        conn.execute(
            text(
                "UPDATE subscription_plans SET price = :price, trial_days = :trial_days "
                "WHERE code = :code"
            ),
            {"price": price, "trial_days": trial_days, "code": code},
        )

    conn.execute(
        text(
            "UPDATE subscription_plans SET contact_links = CAST(:links AS JSON) "
            "WHERE code = 'ENTERPRISE'"
        ),
        {"links": ENTERPRISE_CONTACT_LINKS},
    )

    for code, feature_code, enabled, limit_value in PLAN_ENTITLEMENTS:
        conn.execute(
            text(
                """
                INSERT INTO plan_entitlements (id, plan_id, feature_code, enabled, limit_value, created_at, updated_at)
                SELECT gen_random_uuid(), sp.id, :feature_code, :enabled, :limit_value, now(), now()
                FROM subscription_plans sp
                WHERE sp.code = :code
                ON CONFLICT (plan_id, feature_code)
                DO UPDATE SET enabled = EXCLUDED.enabled, limit_value = EXCLUDED.limit_value
                """
            ),
            {"code": code, "feature_code": feature_code, "enabled": enabled, "limit_value": limit_value},
        )


def downgrade() -> None:
    # Pricing/limits repricing — the pre-change values aren't worth restoring
    # (see k7l1m5n9o3p7 for the same reasoning on the prior data migration).
    pass
