"""add_passenger_requests_table

Revision ID: 0f43ff5b4e44
Revises: 76bd2df17fc5
Create Date: 2026-03-15 21:08:08.688709

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0f43ff5b4e44'
down_revision = '76bd2df17fc5'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'passenger_requests',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('origin_lat', sa.Float(), nullable=False),
        sa.Column('origin_lng', sa.Float(), nullable=False),
        sa.Column('destination_lat', sa.Float(), nullable=False),
        sa.Column('destination_lng', sa.Float(), nullable=False),
        sa.Column('departure_time', sa.DateTime(), nullable=False),
        sa.Column('country', sa.String(length=50), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='open'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['employees.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('idx_passenger_requests_status', 'passenger_requests', ['status'])
    op.create_index('idx_passenger_requests_user_id', 'passenger_requests', ['user_id'])
    op.create_index('idx_passenger_requests_country', 'passenger_requests', ['country'])
    op.create_index('idx_passenger_requests_departure_time', 'passenger_requests', ['departure_time'])


def downgrade():
    op.drop_index('idx_passenger_requests_departure_time', table_name='passenger_requests')
    op.drop_index('idx_passenger_requests_country', table_name='passenger_requests')
    op.drop_index('idx_passenger_requests_user_id', table_name='passenger_requests')
    op.drop_index('idx_passenger_requests_status', table_name='passenger_requests')
    op.drop_table('passenger_requests')
