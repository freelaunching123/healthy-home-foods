"""add_charge_0_to_5_km

Revision ID: 50ccac5a569e
Revises: ef311fe459d5
Create Date: 2026-07-03 19:27:28.852246

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '50ccac5a569e'
down_revision = 'ef311fe459d5'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('admin_settings', sa.Column('delivery_charge_0_to_5_km', sa.Numeric(precision=8, scale=2), server_default='0.00', nullable=False))


def downgrade() -> None:
    op.drop_column('admin_settings', 'delivery_charge_0_to_5_km')
