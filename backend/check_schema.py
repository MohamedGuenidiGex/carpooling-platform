"""Quick script to check if coordinate columns exist in rides table"""
from app import create_app
from app.extensions import db
from sqlalchemy import inspect

app = create_app('development')

with app.app_context():
    inspector = inspect(db.engine)
    columns = inspector.get_columns('rides')
    
    print("Columns in 'rides' table:")
    for col in columns:
        print(f"  - {col['name']}: {col['type']}")
    
    # Check specifically for coordinate columns
    column_names = [col['name'] for col in columns]
    coord_columns = ['origin_lat', 'origin_lng', 'destination_lat', 'destination_lng']
    
    print("\nCoordinate columns check:")
    for coord_col in coord_columns:
        exists = coord_col in column_names
        print(f"  {coord_col}: {'✓ EXISTS' if exists else '✗ MISSING'}")
