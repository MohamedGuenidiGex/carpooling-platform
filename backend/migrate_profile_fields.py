#!/usr/bin/env python3
"""
Migration Script: Add Carpool Profile Fields to Employees Table

Adds phone_number, car_model, car_plate, car_color columns.
Preserves all existing data.

Usage:
    cd backend
    python migrate_profile_fields.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.extensions import db

def migrate():
    """Add profile fields to employees table."""
    app = create_app('development')
    
    with app.app_context():
        print("=" * 60)
        print("MIGRATION: Add Profile Fields to Employees")
        print("=" * 60)
        
        # Check which columns already exist
        with db.engine.connect() as conn:
            result = conn.execute(db.text("PRAGMA table_info(employees)"))
            existing_columns = {row[1] for row in result.fetchall()}
        
        new_columns = {
            'phone_number': 'VARCHAR(20)',
            'car_model': 'VARCHAR(100)',
            'car_plate': 'VARCHAR(20)',
            'car_color': 'VARCHAR(50)'
        }
        
        columns_added = 0
        for col_name, col_type in new_columns.items():
            if col_name not in existing_columns:
                print(f"\n[ ] Adding column: {col_name} ({col_type})")
                with db.engine.connect() as conn:
                    conn.execute(db.text(f"ALTER TABLE employees ADD COLUMN {col_name} {col_type}"))
                    conn.commit()
                print(f"    ✓ Added {col_name}")
                columns_added += 1
            else:
                print(f"    ✓ Column {col_name} already exists, skipping")
        
        print(f"\n{'=' * 60}")
        if columns_added > 0:
            print(f"✅ Migration complete! Added {columns_added} new column(s).")
        else:
            print("✅ All columns already exist. No changes needed.")
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
