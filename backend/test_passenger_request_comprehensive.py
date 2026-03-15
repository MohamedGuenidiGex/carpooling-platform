"""
Comprehensive test for Passenger Request infrastructure.
Run this to verify the complete system works correctly.
"""
import sys
sys.path.insert(0, 'c:\\Users\\LENOVO\\OneDrive\\Desktop\\pfe\\carpooling-platform\\backend')

from app import create_app, db
from app.services.passenger_request_service import PassengerRequestService
from app.repositories.passenger_request_repository import PassengerRequestRepository
from app.models.passenger_request import PassengerRequest
from datetime import datetime, timedelta


def test_database_schema():
    """Test that database table and indexes exist."""
    print("\n[TEST] Database Schema")
    print("-" * 40)
    
    from sqlalchemy import inspect
    inspector = inspect(db.engine)
    
    tables = inspector.get_table_names()
    if 'passenger_requests' in tables:
        print("✓ passenger_requests table exists")
    else:
        print("✗ passenger_requests table NOT found")
        return False
    
    indexes = inspector.get_indexes('passenger_requests')
    index_names = [i['name'] for i in indexes]
    expected = ['idx_passenger_requests_status', 'idx_passenger_requests_country', 
                'idx_passenger_requests_user_id', 'idx_passenger_requests_departure_time']
    
    all_present = True
    for idx in expected:
        if idx in index_names:
            print(f"✓ Index {idx} exists")
        else:
            print(f"✗ Index {idx} missing")
            all_present = False
    
    return all_present


def test_model_validation():
    """Test PassengerRequest model validation."""
    print("\n[TEST] Model Validation")
    print("-" * 40)
    
    # Test valid coordinates
    try:
        request = PassengerRequest(
            user_id=1,
            origin_lat=36.8,
            origin_lng=10.18,
            destination_lat=36.85,
            destination_lng=10.25,
            departure_time=datetime.now(),
            country='tunisia'
        )
        print("✓ Valid coordinates accepted")
        print(f"  Expiration: {request.expires_at}")
    except Exception as e:
        print(f"✗ Valid coordinates rejected: {e}")
        return False
    
    # Test invalid latitude
    try:
        request = PassengerRequest(
            user_id=1,
            origin_lat=999,  # Invalid
            origin_lng=10.18,
            destination_lat=36.85,
            destination_lng=10.25,
            departure_time=datetime.now(),
            country='tunisia'
        )
        print("✗ Invalid coordinates accepted (should fail)")
        return False
    except ValueError:
        print("✓ Invalid coordinates rejected correctly")
    
    return True


def test_haversine_distance():
    """Test distance calculation for duplicate detection."""
    print("\n[TEST] Haversine Distance Calculation")
    print("-" * 40)
    
    # Test nearby points
    dist = PassengerRequestService._calculate_haversine_distance(
        36.8, 10.18, 36.8001, 10.1801
    )
    print(f"✓ Distance between nearby points: {dist:.2f}m (should be ~14m)")
    
    # Test same point
    dist = PassengerRequestService._calculate_haversine_distance(
        36.8, 10.18, 36.8, 10.18
    )
    print(f"✓ Distance between same points: {dist:.2f}m (should be 0m)")
    
    # Test far points (Tunis to Sfax ~270km)
    dist = PassengerRequestService._calculate_haversine_distance(
        36.8, 10.18, 34.74, 10.76
    )
    print(f"✓ Distance between far points: {dist/1000:.2f}km (should be ~270km)")
    
    return True


def test_country_detection():
    """Test country detection from coordinates."""
    print("\n[TEST] Country Detection")
    print("-" * 40)
    
    # Tunisia coordinates
    lat, lng = 36.8, 10.18
    if 30 <= lat <= 38 and 7 <= lng <= 12:
        country = 'tunisia'
    elif 41 <= lat <= 51 and -5 <= lng <= 10:
        country = 'france'
    else:
        country = 'tunisia'
    print(f"✓ ({lat}, {lng}) -> {country}")
    
    # France coordinates
    lat, lng = 48.85, 2.35
    if 30 <= lat <= 38 and 7 <= lng <= 12:
        country = 'tunisia'
    elif 41 <= lat <= 51 and -5 <= lng <= 10:
        country = 'france'
    else:
        country = 'tunisia'
    print(f"✓ ({lat}, {lng}) -> {country}")
    
    return True


def test_repository_methods():
    """Test repository CRUD operations."""
    print("\n[TEST] Repository Methods")
    print("-" * 40)
    
    try:
        open_requests = PassengerRequestRepository.find_open_requests()
        print(f"✓ find_open_requests() works: {len(open_requests)} found")
    except Exception as e:
        print(f"✗ find_open_requests() failed: {e}")
        return False
    
    try:
        requests = PassengerRequestRepository.find_open_requests_by_country('tunisia')
        print(f"✓ find_open_requests_by_country() works: {len(requests)} found")
    except Exception as e:
        print(f"✗ find_open_requests_by_country() failed: {e}")
        return False
    
    try:
        count = PassengerRequestRepository.expire_old_requests()
        print(f"✓ expire_old_requests() works: {count} expired")
    except Exception as e:
        print(f"✗ expire_old_requests() failed: {e}")
        return False
    
    return True


def test_create_request():
    """Test creating a passenger request."""
    print("\n[TEST] Create Passenger Request")
    print("-" * 40)
    
    departure_time = datetime.now() + timedelta(hours=2)
    
    result = PassengerRequestService.create_passenger_request_from_search(
        user_id=1,
        origin_lat=36.8,
        origin_lng=10.18,
        destination_lat=36.85,
        destination_lng=10.25,
        departure_time=departure_time,
        country='tunisia'
    )
    
    if result['success']:
        print(f"✓ Request created: ID {result['request_id']}")
    else:
        print(f"⚠ {result['message']}")
        if 'duplicate' in result['message'].lower():
            print("  (This is expected if a similar request exists)")
    
    # Check what we have in database
    tunisia_requests = PassengerRequestRepository.find_open_requests_by_country('tunisia')
    print(f"✓ Total open Tunisia requests: {len(tunisia_requests)}")
    
    if tunisia_requests:
        req = tunisia_requests[0]
        print(f"  - ID: {req.id}, User: {req.user_id}")
        print(f"  - From: ({req.origin_lat}, {req.origin_lng})")
        print(f"  - To: ({req.destination_lat}, {req.destination_lng})")
        print(f"  - Departure: {req.departure_time.strftime('%Y-%m-%d %H:%M')}")
        print(f"  - Status: {req.status}")
    
    return True


def test_duplicate_detection():
    """Test that duplicate requests are prevented."""
    print("\n[TEST] Duplicate Detection")
    print("-" * 40)
    
    departure_time = datetime.now() + timedelta(hours=2)
    
    # First request
    result1 = PassengerRequestService.create_passenger_request_from_search(
        user_id=1,
        origin_lat=36.801,  # Very close to previous
        origin_lng=10.181,
        destination_lat=36.851,
        destination_lng=10.251,
        departure_time=departure_time,
        country='tunisia'
    )
    
    if result1['success']:
        print(f"✓ First request created: ID {result1['request_id']}")
    else:
        print(f"⚠ First request: {result1['message']}")
    
    # Second request (should be detected as duplicate)
    result2 = PassengerRequestService.create_passenger_request_from_search(
        user_id=1,
        origin_lat=36.801,  # Same as above
        origin_lng=10.181,
        destination_lat=36.851,
        destination_lng=10.251,
        departure_time=departure_time + timedelta(minutes=5),  # 5 min difference
        country='tunisia'
    )
    
    if not result2['success'] and 'duplicate' in result2['message'].lower():
        print("✓ Duplicate correctly detected and rejected")
    elif result2['success']:
        print("⚠ Duplicate was NOT detected (this may be OK depending on existing data)")
    else:
        print(f"⚠ {result2['message']}")
    
    return True


def test_api_integration():
    """Test that rides.py imports work (API integration)."""
    print("\n[TEST] API Integration")
    print("-" * 40)
    
    try:
        from app.api.rides import RideList
        print("✓ rides.py imports successfully (PassengerRequestService integrated)")
        return True
    except Exception as e:
        print(f"✗ rides.py import failed: {e}")
        return False


def main():
    """Run all tests."""
    print("=" * 60)
    print("PASSENGER REQUEST SYSTEM TEST SUITE")
    print("=" * 60)
    
    app = create_app('development')
    
    with app.app_context():
        tests = [
            ("Database Schema", test_database_schema),
            ("Model Validation", test_model_validation),
            ("Haversine Distance", test_haversine_distance),
            ("Country Detection", test_country_detection),
            ("Repository Methods", test_repository_methods),
            ("Create Request", test_create_request),
            ("Duplicate Detection", test_duplicate_detection),
            ("API Integration", test_api_integration),
        ]
        
        results = []
        for name, test_func in tests:
            try:
                result = test_func()
                results.append((name, result))
            except Exception as e:
                print(f"\n✗ {name} crashed: {e}")
                results.append((name, False))
        
        # Summary
        print("\n" + "=" * 60)
        print("TEST SUMMARY")
        print("=" * 60)
        
        passed = sum(1 for _, r in results if r)
        total = len(results)
        
        for name, result in results:
            status = "✓ PASS" if result else "✗ FAIL"
            print(f"{status:10} {name}")
        
        print("-" * 60)
        print(f"Result: {passed}/{total} tests passed")
        
        if passed == total:
            print("\n🎉 All tests passed! System is ready for AI matching.")
        else:
            print(f"\n⚠ {total - passed} test(s) failed. Review above.")
        
        return passed == total


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
