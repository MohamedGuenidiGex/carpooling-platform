"""widen notification type column to 50 chars

Revision ID: aed5f88a9625
Revises: 0861d3e286c7
Create Date: 2026-03-02 14:01:54.587218

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'aed5f88a9625'
down_revision = '0861d3e286c7'
branch_labels = None
depends_on = None


def upgrade():
    op.alter_column('notifications', 'type',
                     existing_type=sa.String(20),
                     type_=sa.String(50),
                     existing_nullable=True)


def downgrade():
    op.alter_column('notifications', 'type',
                     existing_type=sa.String(50),
                     type_=sa.String(20),
                     existing_nullable=True)
