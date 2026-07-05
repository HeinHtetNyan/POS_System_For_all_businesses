"""normalize_user_phone_numbers

Revision ID: d3f8a92b6c17
Revises: a6f07111fd7e
Create Date: 2026-07-05 00:00:00.000000

Backfills users.phone to a canonical digits-only form (keeping a leading '+'
if present), matching the normalization now applied at write time
(UserService.create_user/update_user, RegistrationService.register) and at
login lookup time (AuthService.login). Without this, staff accounts created
before this fix — with a phone stored as e.g. "09 123 456 789" — would never
match what a person actually types at login ("09123456789"), since the
lookup is an exact string comparison.
"""
from __future__ import annotations

from alembic import op

# revision identifiers, used by Alembic.
revision = "d3f8a92b6c17"
down_revision = "a6f07111fd7e"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        UPDATE users
        SET phone = (
            CASE WHEN phone LIKE '+%' THEN '+' ELSE '' END
            || regexp_replace(phone, '[^0-9]', '', 'g')
        )
        WHERE phone IS NOT NULL
          AND regexp_replace(phone, '[^0-9]', '', 'g') != ''
        """
    )


def downgrade() -> None:
    # Original formatting isn't recoverable — this is a one-way data cleanup.
    pass
