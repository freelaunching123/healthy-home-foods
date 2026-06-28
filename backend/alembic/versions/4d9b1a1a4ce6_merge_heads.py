"""merge heads

Revision ID: 4d9b1a1a4ce6
Revises: 0ced161c4100, 54565e780e3d
Create Date: 2026-06-27 13:42:17.517961

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '4d9b1a1a4ce6'
down_revision = ('0ced161c4100', '54565e780e3d')
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
