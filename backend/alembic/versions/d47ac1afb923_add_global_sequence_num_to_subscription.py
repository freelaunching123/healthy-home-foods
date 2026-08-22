"""Add global_sequence_num to Subscription

Revision ID: d47ac1afb923
Revises: 5b262b1fbf5f
Create Date: 2026-08-22 10:30:55.165742

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd47ac1afb923'
down_revision = '5b262b1fbf5f'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create the sequence
    op.execute(sa.schema.CreateSequence(sa.Sequence('subscription_order_number_seq')))
    
    # Add the column using the sequence for defaults
    op.add_column('subscriptions', sa.Column('order_number_seq', sa.Integer(), server_default=sa.text("nextval('subscription_order_number_seq')"), nullable=True))
    op.create_unique_constraint('uq_subscription_order_number_seq', 'subscriptions', ['order_number_seq'])


def downgrade() -> None:
    op.drop_constraint('uq_subscription_order_number_seq', 'subscriptions', type_='unique')
    op.drop_column('subscriptions', 'order_number_seq')
    op.execute(sa.schema.DropSequence(sa.Sequence('subscription_order_number_seq')))
