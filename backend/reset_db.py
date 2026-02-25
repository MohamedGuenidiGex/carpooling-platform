#!/usr/bin/env python3
"""
Quick Database Reset

Drops and recreates all tables without seeding.
"""

import os
import sys

# Add the backend directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db

def main():
    app = create_app(os.getenv('FLASK_ENV') or 'development')
    
    with app.app_context():
        print("Dropping all tables...")
        db.drop_all()
        
        print("Creating fresh tables...")
        db.create_all()
        
        print("Database reset complete - no data seeded")

if __name__ == "__main__":
    main()
