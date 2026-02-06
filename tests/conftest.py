"""Pytest configuration and fixtures for carpooling platform tests.

This module provides:
- Test app and client fixtures
- Database setup/teardown
- Test user fixtures (drivers, passengers)
- Authentication fixtures (tokens)
- Helper fixtures for common test scenarios
"""
import pytest
import sys
import os
import uuid

# Add parent directory to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app import create_app
from app.extensions import db
from app.models import Employee, Ride, Reservation, Notification
from tests.config import TestConfig


@pytest.fixture(scope='session')
def app():
    """Create and configure test Flask application."""
    app = create_app('testing')
    app.config.from_object(TestConfig)
    
    # Create all tables
    with app.app_context():
        db.create_all()
        yield app
        # Clean up after all tests
        db.drop_all()


@pytest.fixture
def client(app):
    """Create test client for making HTTP requests."""
    return app.test_client()


@pytest.fixture
def test_driver(app):
    """Create a test driver employee - no cleanup, db.drop_all handles it."""
    unique_id = str(uuid.uuid4())[:8]
    with app.app_context():
        driver = Employee(
            name=f'Test Driver {unique_id}',
            email=f'driver_{unique_id}@test.com',
            department='Engineering'
        )
        driver.set_password('testpass123')
        db.session.add(driver)
        db.session.commit()
        db.session.refresh(driver)
        
        # Return proxy to access after session closes
        return type('DriverProxy', (), {
            'id': driver.id,
            'email': driver.email,
            'name': driver.name
        })()


@pytest.fixture
def test_passenger(app):
    """Create a test passenger employee - no cleanup, db.drop_all handles it."""
    unique_id = str(uuid.uuid4())[:8]
    with app.app_context():
        passenger = Employee(
            name=f'Test Passenger {unique_id}',
            email=f'passenger_{unique_id}@test.com',
            department='Sales'
        )
        passenger.set_password('testpass123')
        db.session.add(passenger)
        db.session.commit()
        db.session.refresh(passenger)
        
        return type('PassengerProxy', (), {
            'id': passenger.id,
            'email': passenger.email,
            'name': passenger.name
        })()


@pytest.fixture
def driver_token(client, test_driver):
    """Get authentication token for test driver."""
    response = client.post('/auth/login', json={
        'email': test_driver.email,
        'password': 'testpass123'
    })
    assert response.status_code == 200
    return response.json['access_token']


@pytest.fixture
def passenger_token(client, test_passenger):
    """Get authentication token for test passenger."""
    response = client.post('/auth/login', json={
        'email': test_passenger.email,
        'password': 'testpass123'
    })
    assert response.status_code == 200
    return response.json['access_token']


@pytest.fixture
def auth_headers_driver(driver_token):
    """Create authorization headers for driver requests."""
    return {'Authorization': f'Bearer {driver_token}'}


@pytest.fixture
def auth_headers_passenger(passenger_token):
    """Create authorization headers for passenger requests."""
    return {'Authorization': f'Bearer {passenger_token}'}


@pytest.fixture
def sample_ride(app, test_driver):
    """Create a sample ride for testing - no cleanup, db.drop_all handles it."""
    from datetime import datetime, timedelta
    
    with app.app_context():
        ride = Ride(
            driver_id=test_driver.id,
            origin='Downtown',
            destination='Airport',
            departure_time=datetime.now() + timedelta(hours=2),
            available_seats=3,
            status='ACTIVE'
        )
        db.session.add(ride)
        db.session.commit()
        db.session.refresh(ride)
        
        return type('RideProxy', (), {
            'id': ride.id,
            'driver_id': ride.driver_id,
            'origin': ride.origin,
            'destination': ride.destination,
            'available_seats': ride.available_seats,
            'status': ride.status
        })()


@pytest.fixture
def sample_reservation(app, sample_ride, test_passenger):
    """Create a sample reservation - no cleanup, db.drop_all handles it."""
    with app.app_context():
        reservation = Reservation(
            employee_id=test_passenger.id,
            ride_id=sample_ride.id,
            seats_reserved=1,
            status='PENDING'
        )
        db.session.add(reservation)
        db.session.commit()
        db.session.refresh(reservation)
        
        return type('ReservationProxy', (), {
            'id': reservation.id,
            'employee_id': reservation.employee_id,
            'ride_id': reservation.ride_id,
            'seats_reserved': reservation.seats_reserved,
            'status': reservation.status
        })()


@pytest.fixture
def confirmed_reservation(app, sample_ride, test_passenger):
    """Create a confirmed reservation - no cleanup, db.drop_all handles it."""
    with app.app_context():
        # Deduct seats
        ride = Ride.query.get(sample_ride.id)
        ride.available_seats -= 1
        
        reservation = Reservation(
            employee_id=test_passenger.id,
            ride_id=sample_ride.id,
            seats_reserved=1,
            status='CONFIRMED'
        )
        db.session.add(reservation)
        db.session.commit()
        db.session.refresh(reservation)
        
        return type('ReservationProxy', (), {
            'id': reservation.id,
            'employee_id': reservation.employee_id,
            'ride_id': reservation.ride_id,
            'seats_reserved': reservation.seats_reserved,
            'status': reservation.status
        })()
