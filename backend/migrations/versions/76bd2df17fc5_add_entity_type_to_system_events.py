"""add_entity_type_to_system_events

Revision ID: 76bd2df17fc5
Revises: 8918c9a25a6b
Create Date: 2026-03-12 12:02:45.530230

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '76bd2df17fc5'
down_revision = '8918c9a25a6b'
branch_labels = None
depends_on = None


def upgrade():
    # Add entity_type column to system_events table
    with op.batch_alter_table('system_events', schema=None) as batch_op:
        batch_op.add_column(sa.Column('entity_type', sa.String(length=20), nullable=True))


def downgrade():
    # Remove entity_type column
    with op.batch_alter_table('system_events', schema=None) as batch_op:
        batch_op.drop_column('entity_type')
