"""Check if ride ID 5 has coordinates"""
from app import create_app
from app.extensions import db
from app.models import Ride

app = create_app('development')

with app.app_context():
    ride = Ride.query.get(5)
    
    if not ride:
        print("Ride ID 5 not found")
    else:
        print(f"Ride ID 5:")
        print(f"  Origin: {ride.origin}")
        print(f"  origin_lat: {ride.origin_lat}")
        print(f"  origin_lng: {ride.origin_lng}")
        print(f"  Destination: {ride.destination}")
        print(f"  destination_lat: {ride.destination_lat}")
        print(f"  destination_lng: {ride.destination_lng}")
        print(f"  Created at: {ride.created_at}")
        
        if ride.origin_lat is None:
            print("\n❌ This ride has NULL coordinates")
            print("This ride was created BEFORE coordinates were being saved.")
            print("You need to create a NEW ride to test GPS validation.")
        else:
            print("\n✅ This ride has coordinates!")
