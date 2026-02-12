#!/usr/bin/env python3
"""
Migration Script: Update Notifications Table

Adds 'type' column and makes 'ride_id' nullable.
Preserves all existing data.

Usage:
    cd backend
    python migrate_notifications.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.extensions import db

def migrate():
    """Update notifications table with new columns."""
    app = create_app('development')
    
    with app.app_context():
        print("=" * 60)
        print("MIGRATION: Update Notifications Table")
        print("=" * 60)
        
        # Check which columns already exist
        with db.engine.connect() as conn:
            result = conn.execute(db.text("PRAGMA table_info(notifications)"))
            columns = {row[1]: row for row in result.fetchall()}
        
        # Check if ride_id is nullable (notnull = 0 means nullable)
        ride_id_nullable = columns.get('ride_id', [None, None, None, 1])[3] == 0
        
        # Add 'type' column if not exists
        if 'type' not in columns:
            print("\n[ ] Adding column: type (VARCHAR(20), default='info')")
            with db.engine.connect() as conn:
                conn.execute(db.text("ALTER TABLE notifications ADD COLUMN type VARCHAR(20) DEFAULT 'info'"))
                conn.commit()
            print("    ✓ Added type column")
        else:
            print("    ✓ Column 'type' already exists, skipping")
        
        # Make ride_id nullable if currently non-nullable
        if 'ride_id' in columns and not ride_id_nullable:
            print("\n[ ] Making ride_id nullable...")
            # SQLite doesn't support ALTER COLUMN directly, need to recreate table
            with db.engine.connect() as conn:
                # Create new table with updated schema
                conn.execute(db.text("""
                    CREATE TABLE notifications_new (
                        id INTEGER PRIMARY KEY,
                        employee_id INTEGER NOT NULL,
                        ride_id INTEGER,
                        message TEXT NOT NULL,
                        type VARCHAR(20) DEFAULT 'info',
                        is_read BOOLEAN DEFAULT 0,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (employee_id) REFERENCES employees (id),
                        FOREIGN KEY (ride_id) REFERENCES rides (id)
                    )
                """))
                
                # Copy data from old table
                conn.execute(db.text("""
                    INSERT INTO notifications_new (id, employee_id, ride_id, message, is_read, created_at)
                    SELECT id, employee_id, ride_id, message, is_read, created_at FROM notifications
                """))
                
                # Drop old table and rename new one
                conn.execute(db.text("DROP TABLE notifications"))
                conn.execute(db.text("ALTER TABLE notifications_new RENAME TO notifications"))
                conn.commit()
            print("    ✓ Made ride_id nullable (table recreated)")
        else:
            print("    ✓ ride_id is already nullable or doesn't exist, skipping")
        
        print(f"\n{'=' * 60}")
        print("✅ Migration complete!")
        print("=" * 60)

if __name__ == '__main__':
    try:
        migrate()
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Migration failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
