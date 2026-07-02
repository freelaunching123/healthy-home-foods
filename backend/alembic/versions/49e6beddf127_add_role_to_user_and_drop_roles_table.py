"""Add role to User and drop roles table

Revision ID: 49e6beddf127
Revises: bc5762e142de
Create Date: 2026-06-27 21:28:19.372814

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '49e6beddf127'
down_revision = 'bc5762e142de'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Create enum type
    user_role_enum = postgresql.ENUM('customer', 'admin', 'super_admin', 'delivery_partner', name='user_role_enum')
    user_role_enum.create(op.get_bind(), checkfirst=True)

    # Add role column
    op.add_column('users', sa.Column('role', user_role_enum, server_default='customer', nullable=False))

    # Data migration: map user_roles to users.role
    op.execute("""
        UPDATE users u
        SET role = CAST(r.name AS user_role_enum)
        FROM user_roles ur
        JOIN roles r ON ur.role_id = r.id
        WHERE ur.user_id = u.id
    """)

    # Drop old tables
    op.drop_index('ix_user_roles_id', table_name='user_roles')
    op.drop_index('ix_user_roles_user_id', table_name='user_roles')
    op.drop_table('user_roles')
    op.drop_index('ix_roles_id', table_name='roles')
    op.drop_index('ix_roles_name', table_name='roles')
    op.drop_table('roles')

def downgrade() -> None:
    op.create_table('roles',
        sa.Column('id', sa.UUID(), autoincrement=False, nullable=False),
        sa.Column('name', sa.VARCHAR(length=50), autoincrement=False, nullable=False),
        sa.Column('description', sa.VARCHAR(length=255), autoincrement=False, nullable=True),
        sa.Column('created_at', postgresql.TIMESTAMP(timezone=True), server_default=sa.text('now()'), autoincrement=False, nullable=False),
        sa.Column('updated_at', postgresql.TIMESTAMP(timezone=True), server_default=sa.text('now()'), autoincrement=False, nullable=False),
        sa.PrimaryKeyConstraint('id', name='roles_pkey')
    )
    op.create_index('ix_roles_name', 'roles', ['name'], unique=True)
    op.create_index('ix_roles_id', 'roles', ['id'], unique=False)

    op.create_table('user_roles',
        sa.Column('id', sa.UUID(), autoincrement=False, nullable=False),
        sa.Column('user_id', sa.UUID(), autoincrement=False, nullable=False),
        sa.Column('role_id', sa.UUID(), autoincrement=False, nullable=False),
        sa.Column('created_at', postgresql.TIMESTAMP(timezone=True), server_default=sa.text('now()'), autoincrement=False, nullable=False),
        sa.Column('updated_at', postgresql.TIMESTAMP(timezone=True), server_default=sa.text('now()'), autoincrement=False, nullable=False),
        sa.ForeignKeyConstraint(['role_id'], ['roles.id'], name='user_roles_role_id_fkey', ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], name='user_roles_user_id_fkey', ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id', name='user_roles_pkey'),
        sa.UniqueConstraint('user_id', 'role_id', name='uq_user_role')
    )
    op.create_index('ix_user_roles_user_id', 'user_roles', ['user_id'], unique=False)
    op.create_index('ix_user_roles_id', 'user_roles', ['id'], unique=False)

    # Revert data
    op.execute("""
        INSERT INTO roles (id, name, description)
        VALUES 
        (gen_random_uuid(), 'customer', 'Standard Customer'),
        (gen_random_uuid(), 'admin', 'Administrator'),
        (gen_random_uuid(), 'super_admin', 'System Administrator'),
        (gen_random_uuid(), 'delivery_partner', 'Delivery Personnel')
    """)

    op.execute("""
        INSERT INTO user_roles (id, user_id, role_id)
        SELECT gen_random_uuid(), u.id, r.id
        FROM users u
        JOIN roles r ON CAST(r.name AS text) = CAST(u.role AS text)
    """)

    # Drop column and enum
    op.drop_column('users', 'role')
    user_role_enum = postgresql.ENUM('customer', 'admin', 'super_admin', 'delivery_partner', name='user_role_enum')
    user_role_enum.drop(op.get_bind())
