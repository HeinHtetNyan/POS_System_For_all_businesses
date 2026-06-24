"""product name trigram index for fast search

Revision ID: v3w4x5y6z7a8
Revises: u2v3w4x5y6z7
Create Date: 2026-05-30
"""
from alembic import op

revision = 'v3w4x5y6z7a8'
down_revision = 'u2v3w4x5y6z7'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_products_name_trgm
        ON products USING gin (name gin_trgm_ops)
        WHERE is_deleted = false
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_products_name_trgm")
