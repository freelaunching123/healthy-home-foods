"""add_tier_delivery_charges

Revision ID: ef311fe459d5
Revises: 9bd56e75b765
Create Date: 2026-07-03 19:12:43.312435

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'ef311fe459d5'
down_revision = '9bd56e75b765'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('admin_settings', sa.Column('delivery_charge_5_to_10_km', sa.Numeric(precision=8, scale=2), server_default='15.00', nullable=False))
    op.add_column('admin_settings', sa.Column('delivery_charge_10_to_15_km', sa.Numeric(precision=8, scale=2), server_default='25.00', nullable=False))
    op.add_column('admin_settings', sa.Column('max_delivery_distance_km', sa.Numeric(precision=5, scale=2), server_default='15.00', nullable=False))


def downgrade() -> None:
    op.drop_column('admin_settings', 'max_delivery_distance_km')
    op.drop_column('admin_settings', 'delivery_charge_10_to_15_km')
    op.drop_column('admin_settings', 'delivery_charge_5_to_10_km')
