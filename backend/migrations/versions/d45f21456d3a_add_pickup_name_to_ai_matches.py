"""add_pickup_name_to_ai_matches

Revision ID: d45f21456d3a
Revises: cf7fb433d2a8
Create Date: 2026-03-15 21:57:11.955625

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd45f21456d3a'
down_revision = 'cf7fb433d2a8'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('ai_matches', sa.Column('pickup_name', sa.String(length=255), nullable=True))


def downgrade():
    op.drop_column('ai_matches', 'pickup_name')
