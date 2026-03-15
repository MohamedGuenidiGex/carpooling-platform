"""add_ai_matches_table

Revision ID: cf7fb433d2a8
Revises: 0f43ff5b4e44
Create Date: 2026-03-15 21:40:06.132987

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'cf7fb433d2a8'
down_revision = '0f43ff5b4e44'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'ai_matches',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('ride_id', sa.Integer(), nullable=False),
        sa.Column('passenger_request_id', sa.Integer(), nullable=False),
        sa.Column('pickup_lat', sa.Float(), nullable=False),
        sa.Column('pickup_lng', sa.Float(), nullable=False),
        sa.Column('distance_to_route', sa.Float(), nullable=False),
        sa.Column('estimated_detour_minutes', sa.Float(), nullable=False),
        sa.Column('match_score', sa.Float(), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='suggested'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.ForeignKeyConstraint(['ride_id'], ['rides.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['passenger_request_id'], ['passenger_requests.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('ride_id', 'passenger_request_id', name='uq_ride_passenger_match')
    )
    op.create_index('idx_ai_matches_ride_id', 'ai_matches', ['ride_id'])
    op.create_index('idx_ai_matches_passenger_request_id', 'ai_matches', ['passenger_request_id'])
    op.create_index('idx_ai_matches_status', 'ai_matches', ['status'])
    op.create_index('idx_ai_matches_score', 'ai_matches', ['match_score'])


def downgrade():
    op.drop_index('idx_ai_matches_score', table_name='ai_matches')
    op.drop_index('idx_ai_matches_status', table_name='ai_matches')
    op.drop_index('idx_ai_matches_passenger_request_id', table_name='ai_matches')
    op.drop_index('idx_ai_matches_ride_id', table_name='ai_matches')
    op.drop_table('ai_matches')
