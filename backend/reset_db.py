#!/usr/bin/env python3
"""
Database Reset Script - Clean Slate

Drops all tables, recreates them, and seeds ONLY test users.
No mock rides, reservations, or notifications.

Usage:
    cd backend
    python reset_db.py
"""

import os
import sys

# Add the parent directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.extensions import db
from app.models import Employee

# Test users configuration
TEST_USERS = [
    {
        'name': 'Admin User',
        'email': 'admin@gexpertise.fr',
        'password': 'password123',
        'department': 'IT'
    },
    {
        'name': 'Regular User',
        'email': 'user@gexpertise.fr',
        'password': 'password123',
        'department': 'Operations'
    }
]


def reset_database():
    """Reset database to clean state with only test users."""
    app = create_app('development')
    
    with app.app_context():
        print("=" * 60)
        print("DATABASE RESET - CLEAN SLATE")
        print("=" * 60)
        
        # Step 1: Drop all tables
        print("\n[1/4] Dropping all tables...")
        db.drop_all()
        print("✓ All tables dropped")
        
        # Step 2: Recreate tables
        print("\n[2/4] Recreating tables...")
        db.create_all()
        print("✓ Tables recreated")
        
        # Step 3: Add test users only
        print("\n[3/4] Creating test users...")
        for user_data in TEST_USERS:
            # Check if user already exists
            existing = Employee.query.filter_by(email=user_data['email']).first()
            if existing:
                print(f"  ⚠ User {user_data['email']} already exists, skipping")
                continue
            
            # Create new employee with hashed password
            employee = Employee(
                name=user_data['name'],
                email=user_data['email'],
                department=user_data['department']
            )
            employee.set_password(user_data['password'])
            db.session.add(employee)
            print(f"  ✓ Created user: {user_data['email']} / {user_data['password']}")
        
        db.session.commit()
        print("✓ Test users committed to database")
        
        # Step 4: Verify clean state
        print("\n[4/4] Verifying clean state...")
        user_count = Employee.query.count()
        ride_count = db.session.execute(
            db.text("SELECT COUNT(*) FROM rides")
        ).scalar()
        reservation_count = db.session.execute(
            db.text("SELECT COUNT(*) FROM reservations")
        ).scalar()
        notification_count = db.session.execute(
            db.text("SELECT COUNT(*) FROM notifications")
        ).scalar()
        
        print(f"  • Users: {user_count} (expected: {len(TEST_USERS)})")
        print(f"  • Rides: {ride_count} (expected: 0)")
        print(f"  • Reservations: {reservation_count} (expected: 0)")
        print(f"  • Notifications: {notification_count} (expected: 0)")
        
        # Verification check
        if ride_count == 0 and reservation_count == 0 and notification_count == 0:
            print("\n✅ Database is clean and ready for testing!")
        else:
            print("\n⚠️ Warning: Database may contain unexpected data")
        
        print("\n" + "=" * 60)
        print("LOGIN CREDENTIALS:")
        print("=" * 60)
        for user in TEST_USERS:
            print(f"  Email:    {user['email']}")
            print(f"  Password: {user['password']}")
            print()
        print("=" * 60)


if __name__ == '__main__':
    try:
        reset_database()
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
