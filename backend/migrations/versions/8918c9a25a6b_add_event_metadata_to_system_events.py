"""add_event_metadata_to_system_events

Revision ID: 8918c9a25a6b
Revises: aed5f88a9625
Create Date: 2026-03-12 11:40:43.540536

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '8918c9a25a6b'
down_revision = 'aed5f88a9625'
branch_labels = None
depends_on = None


def upgrade():
    # Add event_metadata JSON column to system_events table
    with op.batch_alter_table('system_events', schema=None) as batch_op:
        batch_op.add_column(sa.Column('event_metadata', sa.JSON(), nullable=True))


def downgrade():
    # Remove event_metadata column
    with op.batch_alter_table('system_events', schema=None) as batch_op:
        batch_op.drop_column('event_metadata')
