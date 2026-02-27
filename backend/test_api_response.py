"""Test script to verify API returns coordinates correctly"""
from app import create_app
from app.extensions import db
from app.models import Ride, Employee
from app.api.rides import serialize_ride_with_reservations
from datetime import datetime, timedelta
import json

app = create_app('development')

with app.app_context():
    # Create a test ride with GPS coordinates
    driver = Employee.query.get(2)
    
    test_ride = Ride(
        driver_id=driver.id,
        origin="Test Origin - تونس",
        destination="Test Destination - أريانة",
        origin_lat=33.8439408,
        origin_lng=9.400138,
        destination_lat=36.9685735,
        destination_lng=10.1219855,
        departure_time=datetime.now() + timedelta(hours=2),
        available_seats=3,
        status='scheduled'
    )
    
    db.session.add(test_ride)
    db.session.commit()
    
    print(f"Created test ride ID: {test_ride.id}")
    
    # Test the serialization function
    serialized = serialize_ride_with_reservations(test_ride)
    
    print("\nSerialized ride data:")
    print(json.dumps(serialized, indent=2, ensure_ascii=False))
    
    print("\nCoordinate values in serialized data:")
    print(f"  origin_lat: {serialized.get('origin_lat')}")
    print(f"  origin_lng: {serialized.get('origin_lng')}")
    print(f"  destination_lat: {serialized.get('destination_lat')}")
    print(f"  destination_lng: {serialized.get('destination_lng')}")
    
    if serialized.get('origin_lat') is None:
        print("\n❌ PROBLEM: Coordinates are NULL in API response!")
    else:
        print("\n✅ SUCCESS: Coordinates included in API response!")
    
    # Clean up
    db.session.delete(test_ride)
    db.session.commit()
    print(f"\nTest ride {test_ride.id} deleted.")
