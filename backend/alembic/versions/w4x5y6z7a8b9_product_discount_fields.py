"""add product discount/promotion fields

Revision ID: w4x5y6z7a8b9
Revises: v3w4x5y6z7a8
Create Date: 2026-06-01
"""
from alembic import op
import sqlalchemy as sa

revision = 'w4x5y6z7a8b9'
down_revision = 'v3w4x5y6z7a8'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('products', sa.Column('discount_type', sa.String(20), nullable=True))
    op.add_column('products', sa.Column('discount_value', sa.Numeric(12, 4), nullable=True))
    op.add_column('products', sa.Column('discount_start_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('products', sa.Column('discount_end_at', sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column('products', 'discount_end_at')
    op.drop_column('products', 'discount_start_at')
    op.drop_column('products', 'discount_value')
    op.drop_column('products', 'discount_type')
