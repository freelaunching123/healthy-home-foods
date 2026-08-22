"""Add grocery_order_number_seq

Revision ID: 4d55f01e7abc
Revises: d47ac1afb923
Create Date: 2026-08-22 10:33:24.736443

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '4d55f01e7abc'
down_revision = 'd47ac1afb923'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create the sequence for grocery order numbers
    op.execute(sa.schema.CreateSequence(sa.Sequence('grocery_order_number_seq')))


def downgrade() -> None:
    # Drop the sequence
    op.execute(sa.schema.DropSequence(sa.Sequence('grocery_order_number_seq')))
