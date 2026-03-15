"""add_dynamic_pickup_to_rides

Revision ID: 8dd634fd5814
Revises: d772a6d984a7
Create Date: 2026-03-15 22:22:24.878591

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '8dd634fd5814'
down_revision = 'd772a6d984a7'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('rides', sa.Column('dynamic_pickup_lat', sa.Float(), nullable=True))
    op.add_column('rides', sa.Column('dynamic_pickup_lng', sa.Float(), nullable=True))
    op.add_column('rides', sa.Column('dynamic_pickup_name', sa.String(length=255), nullable=True))


def downgrade():
    op.drop_column('rides', 'dynamic_pickup_name')
    op.drop_column('rides', 'dynamic_pickup_lng')
    op.drop_column('rides', 'dynamic_pickup_lat')
