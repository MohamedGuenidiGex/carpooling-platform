"""Integration test script for carpooling platform backend.

This script tests core user flows end-to-end using HTTP requests.
Run with: python tests/integration_test.py

Requirements:
- Flask server running on http://127.0.0.1:5000
- requests library installed (pip install requests)
"""
import requests
import sys
from datetime import datetime, timedelta

BASE_URL = "http://127.0.0.1:5000"

# Test data
TEST_EMPLOYEE_A = {
    "name": "Test Driver A",
    "email": "test.driver.a@example.com",
    "password": "testpass123",
    "department": "Engineering"
}

TEST_EMPLOYEE_B = {
    "name": "Test Passenger B",
    "email": "test.passenger.b@example.com",
    "password": "testpass123",
    "department": "Sales"
}


def print_header(text):
    """Print a formatted section header."""
    print(f"\n{'=' * 60}")
    print(f"  {text}")
    print(f"{'=' * 60}")


def print_result(test_name, passed, details=""):
    """Print test result with PASS/FAIL status."""
    status = "PASS" if passed else "FAIL"
    icon = "✓" if passed else "✗"
    print(f"{icon} {test_name}: {status}")
    if details and not passed:
        print(f"  Details: {details}")
    return passed


def register_employee(employee_data):
    """Register a new employee and return the employee data with ID."""
    url = f"{BASE_URL}/auth/register"
    response = requests.post(url, json=employee_data)
    
    if response.status_code == 201:
        return response.json()
    elif response.status_code == 409:
        # Employee already exists, try to login to get ID
        login_response = login_employee(employee_data["email"], employee_data["password"])
        if login_response:
            return login_response["employee"]
    return None


def login_employee(email, password):
    """Login an employee and return tokens and employee data."""
    url = f"{BASE_URL}/auth/login"
    response = requests.post(url, json={"email": email, "password": password})
    
    if response.status_code == 200:
        return response.json()
    return None


def create_ride(token, ride_data):
    """Create a new ride and return ride data."""
    url = f"{BASE_URL}/rides/"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(url, json=ride_data, headers=headers)
    
    if response.status_code == 201:
        return response.json()
    return None


def search_rides(token, params=None):
    """Search for available rides."""
    url = f"{BASE_URL}/rides/"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(url, params=params, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    return None


def create_reservation(token, reservation_data):
    """Create a reservation request."""
    url = f"{BASE_URL}/reservations/"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(url, json=reservation_data, headers=headers)
    
    if response.status_code == 201:
        return response.json()
    return None


def approve_reservation(token, reservation_id):
    """Approve a pending reservation."""
    url = f"{BASE_URL}/reservations/{reservation_id}/approve"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.patch(url, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    return None


def get_notifications(token, employee_id):
    """Get notifications for an employee."""
    url = f"{BASE_URL}/notifications/{employee_id}"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    return None


def cancel_reservation(token, reservation_id):
    """Cancel a reservation."""
    url = f"{BASE_URL}/reservations/{reservation_id}/cancel"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.post(url, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    return None


# =============================================================================
# SCENARIO 1: Happy Path - Full User Flow
# =============================================================================

def scenario_1_full_flow():
    """Test complete user flow: register, login, create ride, reserve, approve."""
    print_header("SCENARIO 1: Full User Flow")
    
    all_passed = True
    
    # Step 1: Register Employee A (Driver)
    print("\n[Step 1] Registering Employee A (Driver)...")
    employee_a = register_employee(TEST_EMPLOYEE_A)
    passed = print_result("Register Employee A", employee_a is not None)
    all_passed = all_passed and passed
    
    # Step 2: Register Employee B (Passenger)
    print("\n[Step 2] Registering Employee B (Passenger)...")
    employee_b = register_employee(TEST_EMPLOYEE_B)
    passed = print_result("Register Employee B", employee_b is not None)
    all_passed = all_passed and passed
    
    if not employee_a or not employee_b:
        print("\n✗ Cannot continue without registered employees")
        return False
    
    # Step 3: Login Employee A
    print("\n[Step 3] Logging in Employee A...")
    login_a = login_employee(TEST_EMPLOYEE_A["email"], TEST_EMPLOYEE_A["password"])
    passed = print_result("Login Employee A", login_a is not None)
    all_passed = all_passed and passed
    
    if not login_a:
        return False
    
    token_a = login_a["access_token"]
    
    # Step 4: Employee A creates a ride
    print("\n[Step 4] Employee A creating a ride...")
    departure_time = (datetime.now() + timedelta(days=1)).isoformat()
    ride_data = {
        "driver_id": employee_a["id"],
        "origin": "Downtown",
        "destination": "Airport",
        "departure_time": departure_time,
        "available_seats": 3
    }
    ride = create_ride(token_a, ride_data)
    passed = print_result("Create Ride", ride is not None)
    all_passed = all_passed and passed
    
    if not ride:
        return False
    
    ride_id = ride["id"]
    print(f"  Created ride ID: {ride_id}")
    
    # Step 5: Login Employee B
    print("\n[Step 5] Logging in Employee B...")
    login_b = login_employee(TEST_EMPLOYEE_B["email"], TEST_EMPLOYEE_B["password"])
    passed = print_result("Login Employee B", login_b is not None)
    all_passed = all_passed and passed
    
    if not login_b:
        return False
    
    token_b = login_b["access_token"]
    
    # Step 6: Employee B searches for rides
    print("\n[Step 6] Employee B searching for rides...")
    rides = search_rides(token_b, {"origin": "Downtown"})
    passed = print_result("Search Rides", rides is not None and len(rides.get("items", [])) > 0)
    all_passed = all_passed and passed
    
    # Step 7: Employee B creates a reservation
    print("\n[Step 7] Employee B creating reservation...")
    reservation_data = {
        "employee_id": employee_b["id"],
        "ride_id": ride_id,
        "seats_reserved": 1
    }
    reservation = create_reservation(token_b, reservation_data)
    passed = print_result("Create Reservation", reservation is not None)
    all_passed = all_passed and passed
    
    if not reservation:
        return False
    
    reservation_id = reservation["id"]
    passed = print_result("Reservation Status is PENDING", reservation["status"] == "PENDING")
    all_passed = all_passed and passed
    
    # Step 8: Check notifications for Employee A (driver should be notified)
    print("\n[Step 8] Checking notifications for Employee A (Driver)...")
    notifications_a = get_notifications(token_a, employee_a["id"])
    has_notification = notifications_a is not None and len(notifications_a) > 0
    passed = print_result("Driver Received Notification", has_notification)
    all_passed = all_passed and passed
    
    # Step 9: Employee A approves the reservation
    print("\n[Step 9] Employee A approving reservation...")
    approved = approve_reservation(token_a, reservation_id)
    passed = print_result("Approve Reservation", approved is not None)
    all_passed = all_passed and passed
    
    if approved:
        passed = print_result("Reservation Status is CONFIRMED", approved["status"] == "CONFIRMED")
        all_passed = all_passed and passed
    
    # Step 10: Check notifications for Employee B (passenger should be notified)
    print("\n[Step 10] Checking notifications for Employee B (Passenger)...")
    notifications_b = get_notifications(token_b, employee_b["id"])
    has_notification = notifications_b is not None and len(notifications_b) > 0
    passed = print_result("Passenger Received Notification", has_notification)
    all_passed = all_passed and passed
    
    print(f"\n{'=' * 60}")
    if all_passed:
        print("  SCENARIO 1: ALL TESTS PASSED ✓")
    else:
        print("  SCENARIO 1: SOME TESTS FAILED ✗")
    print(f"{'=' * 60}")
    
    return all_passed


# =============================================================================
# SCENARIO 2: Error Handling
# =============================================================================

def scenario_2_error_handling():
    """Test error scenarios: invalid bookings, unauthorized actions."""
    print_header("SCENARIO 2: Error Handling")
    
    all_passed = True
    
    # Login existing employees
    login_a = login_employee(TEST_EMPLOYEE_A["email"], TEST_EMPLOYEE_A["password"])
    login_b = login_employee(TEST_EMPLOYEE_B["email"], TEST_EMPLOYEE_B["password"])
    
    if not login_a or not login_b:
        print("✗ Cannot run error tests without logged in users")
        return False
    
    token_a = login_a["access_token"]
    token_b = login_b["access_token"]
    employee_a = login_a["employee"]
    employee_b = login_b["employee"]
    
    # Test 1: Attempt to book with invalid seats (0 seats)
    print("\n[Test 1] Attempting to book with 0 seats...")
    url = f"{BASE_URL}/reservations/"
    headers = {"Authorization": f"Bearer {token_b}"}
    invalid_reservation = {
        "employee_id": employee_b["id"],
        "ride_id": 1,
        "seats_reserved": 0
    }
    response = requests.post(url, json=invalid_reservation, headers=headers)
    passed = print_result("Invalid Seats Rejected", response.status_code == 400)
    all_passed = all_passed and passed
    
    # Test 2: Attempt to access protected endpoint without token
    print("\n[Test 2] Accessing protected endpoint without token...")
    url = f"{BASE_URL}/rides/"
    response = requests.get(url)
    passed = print_result("Unauthorized Access Rejected", response.status_code == 401)
    all_passed = all_passed and passed
    
    # Verify error response format
    if response.status_code == 401:
        error_data = response.json()
        has_error_field = "error" in error_data
        passed = print_result("Error Response Has 'error' Field", has_error_field)
        all_passed = all_passed and passed
    
    # Test 3: Attempt to access non-existent ride
    print("\n[Test 3] Accessing non-existent ride...")
    url = f"{BASE_URL}/rides/99999"
    headers = {"Authorization": f"Bearer {token_a}"}
    response = requests.get(url, headers=headers)
    passed = print_result("Non-existent Ride Returns 404", response.status_code == 404)
    all_passed = all_passed and passed
    
    # Test 4: Attempt passenger trying to approve reservation (unauthorized)
    print("\n[Test 4] Passenger attempting to approve reservation...")
    # First create a new reservation
    departure_time = (datetime.now() + timedelta(days=2)).isoformat()
    ride_data = {
        "driver_id": employee_a["id"],
        "origin": "City Center",
        "destination": "Suburbs",
        "departure_time": departure_time,
        "available_seats": 2
    }
    ride = create_ride(token_a, ride_data)
    
    if ride:
        reservation_data = {
            "employee_id": employee_b["id"],
            "ride_id": ride["id"],
            "seats_reserved": 1
        }
        reservation = create_reservation(token_b, reservation_data)
        
        if reservation:
            # Employee B tries to approve their own reservation (should fail)
            url = f"{BASE_URL}/reservations/{reservation['id']}/approve"
            response = requests.patch(url, headers=headers)
            passed = print_result("Unauthorized Approval Rejected", response.status_code == 403)
            all_passed = all_passed and passed
    
    # Test 5: Attempt invalid login credentials
    print("\n[Test 5] Attempting login with invalid credentials...")
    url = f"{BASE_URL}/auth/login"
    invalid_login = {"email": "nonexistent@test.com", "password": "wrongpass"}
    response = requests.post(url, json=invalid_login)
    passed = print_result("Invalid Login Rejected", response.status_code == 401)
    all_passed = all_passed and passed
    
    # Verify error response format
    if response.status_code == 401:
        error_data = response.json()
        has_error_field = "error" in error_data
        has_message_field = "message" in error_data
        passed = print_result("Error Response Has Standardized Format", has_error_field and has_message_field)
        all_passed = all_passed and passed
    
    print(f"\n{'=' * 60}")
    if all_passed:
        print("  SCENARIO 2: ALL TESTS PASSED ✓")
    else:
        print("  SCENARIO 2: SOME TESTS FAILED ✗")
    print(f"{'=' * 60}")
    
    return all_passed


# =============================================================================
# MAIN
# =============================================================================

def main():
    """Run all integration tests."""
    print("\n" + "=" * 60)
    print("  CARPOOLING PLATFORM - INTEGRATION TESTS")
    print("  " + f"Base URL: {BASE_URL}")
    print("=" * 60)
    
    # Check if server is running
    try:
        response = requests.get(f"{BASE_URL}/docs", timeout=5)
        print("\n✓ Server is running and accessible")
    except requests.exceptions.ConnectionError:
        print("\n✗ ERROR: Cannot connect to server at", BASE_URL)
        print("  Please ensure the Flask server is running:")
        print("  $ flask run")
        sys.exit(1)
    
    # Run tests
    scenario1_passed = scenario_1_full_flow()
    scenario2_passed = scenario_2_error_handling()
    
    # Final summary
    print("\n" + "=" * 60)
    print("  FINAL SUMMARY")
    print("=" * 60)
    
    if scenario1_passed and scenario2_passed:
        print("\n✓ ALL INTEGRATION TESTS PASSED")
        print("\nThe backend is working correctly!")
        return 0
    else:
        print("\n✗ SOME INTEGRATION TESTS FAILED")
        print("\nPlease review the failures above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
