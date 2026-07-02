"""rename delivery_boy to delivery_partner

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-12 15:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Rename table
    op.rename_table('delivery_boys', 'delivery_partners')
    
    # Add new columns to delivery_partners
    op.add_column('delivery_partners', sa.Column('age', sa.Integer(), nullable=True))
    op.add_column('delivery_partners', sa.Column('gender', sa.String(length=20), nullable=True))
    op.add_column('delivery_partners', sa.Column('photo_url', sa.String(length=500), nullable=True))
    
    # Rename foreign keys and columns in delivery_assignments
    op.alter_column('delivery_assignments', 'delivery_boy_id', new_column_name='delivery_partner_id')
    
    # Rename foreign keys and columns in gps_tracking_logs
    op.alter_column('gps_tracking_logs', 'delivery_boy_id', new_column_name='delivery_partner_id')
    
    # Rename indexes
    op.execute('ALTER INDEX IF EXISTS ix_assignments_delivery_boy_id RENAME TO ix_assignments_delivery_partner_id')
    op.execute('ALTER INDEX IF EXISTS ix_gps_tracking_logs_delivery_boy_id RENAME TO ix_gps_tracking_logs_delivery_partner_id')
    
    # Update seed data in roles
    op.execute("UPDATE roles SET name = 'delivery_partner' WHERE name = 'delivery_boy'")

def downgrade() -> None:
    pass
