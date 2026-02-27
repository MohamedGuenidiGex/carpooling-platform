"""Check if ride ID 6 has coordinates"""
from app import create_app
from app.extensions import db
from app.models import Ride

app = create_app('development')

with app.app_context():
    ride = Ride.query.get(6)
    
    if not ride:
        print("Ride ID 6 not found")
    else:
        print(f"Ride ID 6:")
        print(f"  Origin: {ride.origin}")
        print(f"  origin_lat: {ride.origin_lat}")
        print(f"  origin_lng: {ride.origin_lng}")
        print(f"  Destination: {ride.destination}")
        print(f"  destination_lat: {ride.destination_lat}")
        print(f"  destination_lng: {ride.destination_lng}")
        print(f"  Status: {ride.status}")
        print(f"  Created at: {ride.created_at}")
        
        if ride.origin_lat is None:
            print("\n❌ This ride has NULL coordinates")
            print("This ride was created BEFORE the coordinate feature was working.")
        else:
            print("\n✅ This ride has coordinates!")
