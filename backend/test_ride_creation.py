"""Test script to create a ride with GPS coordinates and verify they're saved"""
from app import create_app
from app.extensions import db
from app.models import Ride, Employee
from datetime import datetime, timedelta

app = create_app('development')

with app.app_context():
    # Get a driver (employee ID 2 from the logs)
    driver = Employee.query.get(2)
    if not driver:
        print("ERROR: Driver with ID 2 not found")
        exit(1)
    
    print(f"Creating ride for driver: {driver.name} (ID: {driver.id})")
    
    # Create a test ride with GPS coordinates
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
    
    print("\nBefore commit:")
    print(f"  origin_lat: {test_ride.origin_lat}")
    print(f"  origin_lng: {test_ride.origin_lng}")
    print(f"  destination_lat: {test_ride.destination_lat}")
    print(f"  destination_lng: {test_ride.destination_lng}")
    
    db.session.add(test_ride)
    db.session.commit()
    
    print(f"\nRide created with ID: {test_ride.id}")
    print("After commit:")
    print(f"  origin_lat: {test_ride.origin_lat}")
    print(f"  origin_lng: {test_ride.origin_lng}")
    print(f"  destination_lat: {test_ride.destination_lat}")
    print(f"  destination_lng: {test_ride.destination_lng}")
    
    # Fetch the ride again from database to verify
    fetched_ride = Ride.query.get(test_ride.id)
    print(f"\nFetched ride from database (ID: {fetched_ride.id}):")
    print(f"  origin: {fetched_ride.origin}")
    print(f"  origin_lat: {fetched_ride.origin_lat}")
    print(f"  origin_lng: {fetched_ride.origin_lng}")
    print(f"  destination: {fetched_ride.destination}")
    print(f"  destination_lat: {fetched_ride.destination_lat}")
    print(f"  destination_lng: {fetched_ride.destination_lng}")
    
    if fetched_ride.origin_lat is None:
        print("\n❌ PROBLEM: Coordinates are NULL in database!")
    else:
        print("\n✅ SUCCESS: Coordinates saved correctly!")
    
    # Clean up - delete the test ride
    db.session.delete(fetched_ride)
    db.session.commit()
    print(f"\nTest ride {fetched_ride.id} deleted.")
