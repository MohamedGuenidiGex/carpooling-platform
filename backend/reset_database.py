#!/usr/bin/env python3
"""
Database Reset Script

This script completely resets the database by:
1. Dropping all existing tables
2. Creating fresh tables with current schema
3. NOT seeding any initial data

Use this when you want a completely clean database for testing.
"""

import os
import sys

# Add the backend directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from flask_migrate import init, migrate, upgrade, downgrade

def reset_database():
    """Reset the database completely without seeding"""
    app = create_app(os.getenv('FLASK_ENV') or 'development')
    
    with app.app_context():
        print("🗑️  Resetting database...")
        
        try:
            # Drop all tables
            print("   Dropping all existing tables...")
            db.drop_all()
            print("   ✅ All tables dropped")
            
            # Create tables with current schema
            print("   Creating fresh tables...")
            db.create_all()
            print("   ✅ Fresh tables created")
            
            # Apply migrations to ensure schema is up to date
            print("   Applying migrations...")
            try:
                upgrade()
                print("   ✅ Migrations applied")
            except Exception as e:
                print(f"   ⚠️  Migration warning: {e}")
                print("   (This is normal if migrations are already applied)")
            
            print("\n🎉 Database reset complete!")
            print("   - All tables are fresh")
            print("   - No data seeded")
            print("   - Ready for clean testing")
            
        except Exception as e:
            print(f"❌ Error resetting database: {e}")
            sys.exit(1)

if __name__ == "__main__":
    print("=" * 50)
    print("DATABASE RESET SCRIPT")
    print("=" * 50)
    print("⚠️  WARNING: This will delete ALL data!")
    print("   No data will be seeded after reset")
    print()
    
    # Ask for confirmation
    response = input("Are you sure you want to reset the database? (yes/no): ")
    if response.lower() != 'yes':
        print("❌ Database reset cancelled")
        sys.exit(0)
    
    reset_database()
