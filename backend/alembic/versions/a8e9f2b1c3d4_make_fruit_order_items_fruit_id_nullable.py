"""Make fruit_order_items.fruit_id nullable and set ON DELETE SET NULL

Revision ID: a8e9f2b1c3d4
Revises: e17a8f588fe8
Create Date: 2026-07-29 10:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a8e9f2b1c3d4'
down_revision = 'e17a8f588fe8'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Make fruit_id nullable and set FK constraint ondelete to SET NULL
    with op.batch_alter_table('fruit_order_items', schema=None) as batch_op:
        batch_op.alter_column('fruit_id', existing_type=sa.UUID(), nullable=True)
        try:
            batch_op.drop_constraint('fruit_order_items_fruit_id_fkey', type_='foreignkey')
        except Exception:
            pass
        batch_op.create_foreign_key(
            'fruit_order_items_fruit_id_fkey',
            'fruits',
            ['fruit_id'],
            ['id'],
            ondelete='SET NULL'
        )


def downgrade() -> None:
    with op.batch_alter_table('fruit_order_items', schema=None) as batch_op:
        try:
            batch_op.drop_constraint('fruit_order_items_fruit_id_fkey', type_='foreignkey')
        except Exception:
            pass
        batch_op.create_foreign_key(
            'fruit_order_items_fruit_id_fkey',
            'fruits',
            ['fruit_id'],
            ['id'],
            ondelete='RESTRICT'
        )
        batch_op.alter_column('fruit_id', existing_type=sa.UUID(), nullable=False)
