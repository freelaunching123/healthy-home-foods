"""update product pricing

Revision ID: bc5762e142de
Revises: 4d9b1a1a4ce6
Create Date: 2026-06-27 20:50:38.276330

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'bc5762e142de'
down_revision = '4d9b1a1a4ce6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # 1. Add new columns to products
    op.add_column('products', sa.Column('plan_type', sa.String(50), nullable=True))
    op.add_column('products', sa.Column('package_days', sa.Integer(), nullable=True))
    op.add_column('products', sa.Column('package_price', sa.Numeric(10, 2), nullable=True))
    
    # 2. Add columns to subscriptions/subscription_items
    op.add_column('subscriptions', sa.Column('package_price', sa.Numeric(10, 2), nullable=True))
    op.add_column('subscriptions', sa.Column('plan_type', sa.String(50), nullable=True))
    op.add_column('subscription_items', sa.Column('package_price', sa.Numeric(10, 2), nullable=True))

    # 3. Data migration for products (defaulting old records to weekly plan)
    op.execute('''
        UPDATE products 
        SET plan_type = 'weekly',
            package_days = 6,
            package_price = price * 6,
            discount_price = discount_price * 6
    ''')

    # Make them not nullable after migration
    op.alter_column('products', 'plan_type', nullable=False)
    op.alter_column('products', 'package_days', nullable=False)
    op.alter_column('products', 'package_price', nullable=False)

    # 4. Drop old columns
    op.drop_column('products', 'price')
    
    # 5. Alter existing price_per_delivery and plan_id to nullable in subscriptions
    op.alter_column('subscriptions', 'price_per_delivery', nullable=True)
    op.alter_column('subscriptions', 'plan_id', nullable=True)
    op.alter_column('subscription_items', 'price_per_delivery', nullable=True)


def downgrade() -> None:
    # 1. Add back old columns
    op.add_column('products', sa.Column('price', sa.Numeric(10, 2), nullable=True))

    # 2. Revert data
    op.execute('''
        UPDATE products 
        SET price = package_price / 6,
            discount_price = discount_price / 6
    ''')

    op.alter_column('products', 'price', nullable=False)

    # 3. Drop new columns
    op.drop_column('products', 'plan_type')
    op.drop_column('products', 'package_days')
    op.drop_column('products', 'package_price')
    
    op.drop_column('subscriptions', 'package_price')
    op.drop_column('subscriptions', 'plan_type')
    op.drop_column('subscription_items', 'package_price')

    # 4. Revert price_per_delivery and plan_id to nullable=False
    op.alter_column('subscriptions', 'price_per_delivery', nullable=False)
    op.alter_column('subscriptions', 'plan_id', nullable=False)
    op.alter_column('subscription_items', 'price_per_delivery', nullable=False)
