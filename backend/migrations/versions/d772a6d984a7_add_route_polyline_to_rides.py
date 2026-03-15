"""add_route_polyline_to_rides

Revision ID: d772a6d984a7
Revises: d45f21456d3a
Create Date: 2026-03-15 22:01:44.873835

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd772a6d984a7'
down_revision = 'd45f21456d3a'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('rides', sa.Column('route_polyline', sa.Text(), nullable=True))


def downgrade():
    op.drop_column('rides', 'route_polyline')
