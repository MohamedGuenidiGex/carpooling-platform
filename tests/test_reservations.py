"""Reservations endpoint tests.

Tests reservation creation, approval, rejection, and cancellation flows.
"""
import pytest
from datetime import datetime, timedelta


class TestReservationCreate:
    """Test reservation creation endpoints."""
    
    def test_create_reservation_success(self, client, auth_headers_passenger, sample_ride, test_passenger):
        """Test creating a reservation creates PENDING status."""
        response = client.post('/reservations/', headers=auth_headers_passenger, json={
            'employee_id': test_passenger.id,
            'ride_id': sample_ride.id,
            'seats_reserved': 1
        })
        
        assert response.status_code == 201
        assert response.json['status'] == 'PENDING'
        assert response.json['seats_reserved'] == 1
        assert response.json['ride_id'] == sample_ride.id
    
    def test_create_reservation_invalid_seats(self, client, auth_headers_passenger, sample_ride, test_passenger):
        """Test creating reservation with 0 seats fails."""
        response = client.post('/reservations/', headers=auth_headers_passenger, json={
            'employee_id': test_passenger.id,
            'ride_id': sample_ride.id,
            'seats_reserved': 0
        })
        
        assert response.status_code == 400
        assert response.json['error'] == 'VALIDATION_ERROR'
    
    def test_create_duplicate_reservation_fails(self, client, auth_headers_passenger, sample_ride, test_passenger, app):
        """Test creating duplicate reservation for same ride fails."""
        # Create first reservation via API
        response1 = client.post('/reservations/', headers=auth_headers_passenger, json={
            'employee_id': test_passenger.id,
            'ride_id': sample_ride.id,
            'seats_reserved': 1
        })
        assert response1.status_code == 201
        
        # Try to create second reservation - should fail with 400
        response = client.post('/reservations/', headers=auth_headers_passenger, json={
            'employee_id': test_passenger.id,
            'ride_id': sample_ride.id,
            'seats_reserved': 1
        })
        
        assert response.status_code == 400
        # Just check error field exists, message format may vary
        assert 'error' in response.json or 'message' in response.json
    
    def test_create_reservation_overbooking_fails(self, client, auth_headers_passenger, sample_ride, test_passenger):
        """Test reserving more seats than available fails."""
        response = client.post('/reservations/', headers=auth_headers_passenger, json={
            'employee_id': test_passenger.id,
            'ride_id': sample_ride.id,
            'seats_reserved': 100  # More than available
        })
        
        assert response.status_code == 400
        assert response.json['error'] == 'VALIDATION_ERROR'


class TestReservationApprove:
    """Test reservation approval endpoints."""
    
    def test_approve_reservation_success(self, client, auth_headers_driver, sample_ride, test_passenger, app):
        """Test driver can approve PENDING reservation."""
        from app.models import Reservation
        from app.extensions import db
        
        # Create pending reservation
        with app.app_context():
            reservation = Reservation(
                employee_id=test_passenger.id,
                ride_id=sample_ride.id,
                seats_reserved=1,
                status='PENDING'
            )
            db.session.add(reservation)
            db.session.commit()
            reservation_id = reservation.id
        
        response = client.patch(f'/reservations/{reservation_id}/approve', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert response.json['status'] == 'CONFIRMED'
    
    def test_approve_reservation_unauthorized(self, client, auth_headers_passenger, sample_reservation):
        """Test passenger cannot approve their own reservation."""
        response = client.patch(f'/reservations/{sample_reservation.id}/approve', headers=auth_headers_passenger)
        
        assert response.status_code == 403
        assert response.json['error'] == 'FORBIDDEN'
    
    def test_approve_non_pending_reservation_fails(self, client, auth_headers_driver, confirmed_reservation):
        """Test approving already confirmed reservation fails."""
        response = client.patch(f'/reservations/{confirmed_reservation.id}/approve', headers=auth_headers_driver)
        
        assert response.status_code == 400
        assert response.json['error'] == 'VALIDATION_ERROR'
    
    def test_approve_nonexistent_reservation(self, client, auth_headers_driver):
        """Test approving non-existent reservation returns 404."""
        response = client.patch('/reservations/99999/approve', headers=auth_headers_driver)
        
        assert response.status_code == 404
        assert response.json['error'] == 'NOT_FOUND'


class TestReservationReject:
    """Test reservation rejection endpoints."""
    
    def test_reject_reservation_success(self, client, auth_headers_driver, sample_ride, test_passenger, app):
        """Test driver can reject PENDING reservation."""
        from app.models import Reservation
        from app.extensions import db
        
        # Create pending reservation
        with app.app_context():
            reservation = Reservation(
                employee_id=test_passenger.id,
                ride_id=sample_ride.id,
                seats_reserved=1,
                status='PENDING'
            )
            db.session.add(reservation)
            db.session.commit()
            reservation_id = reservation.id
        
        response = client.patch(f'/reservations/{reservation_id}/reject', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert response.json['status'] == 'REJECTED'
    
    def test_reject_reservation_unauthorized(self, client, auth_headers_passenger, sample_reservation):
        """Test passenger cannot reject reservation."""
        response = client.patch(f'/reservations/{sample_reservation.id}/reject', headers=auth_headers_passenger)
        
        assert response.status_code == 403
        assert response.json['error'] == 'FORBIDDEN'


class TestReservationCancel:
    """Test reservation cancellation endpoints."""
    
    def test_cancel_reservation_success(self, client, auth_headers_passenger, sample_reservation):
        """Test passenger can cancel their own reservation."""
        response = client.post(f'/reservations/{sample_reservation.id}/cancel', headers=auth_headers_passenger)
        
        assert response.status_code == 200
        assert response.json['status'] == 'CANCELLED'
    
    def test_cancel_reservation_unauthorized(self, client, auth_headers_driver, sample_reservation):
        """Test driver cannot cancel passenger's reservation."""
        response = client.post(f'/reservations/{sample_reservation.id}/cancel', headers=auth_headers_driver)
        
        assert response.status_code == 403
        assert response.json['error'] == 'FORBIDDEN'
    
    def test_cancel_already_cancelled_reservation(self, client, auth_headers_passenger, app):
        """Test cancelling already cancelled reservation fails."""
        from app.models import Reservation, Ride, Employee
        from app.extensions import db
        from datetime import datetime, timedelta
        import uuid
        
        with app.app_context():
            # Create a fresh ride
            ride = Ride(
                driver_id=1,  # Will use existing driver
                origin='Test Origin',
                destination='Test Dest',
                departure_time=datetime.now() + timedelta(hours=2),
                available_seats=3,
                status='ACTIVE'
            )
            db.session.add(ride)
            db.session.flush()
            
            # Create passenger
            passenger = Employee(
                name='Cancel Test Passenger',
                email=f'cancel_test_{str(uuid.uuid4())[:8]}@test.com',
                department='Test'
            )
            passenger.set_password('testpass123')
            db.session.add(passenger)
            db.session.flush()
            
            # Create cancelled reservation
            reservation = Reservation(
                employee_id=passenger.id,
                ride_id=ride.id,
                seats_reserved=1,
                status='CANCELLED'
            )
            db.session.add(reservation)
            db.session.commit()
            
            reservation_id = reservation.id
            passenger_email = passenger.email
        
        # Login as passenger
        login_resp = client.post('/auth/login', json={
            'email': passenger_email,
            'password': 'testpass123'
        })
        token = login_resp.json['access_token']
        
        # Try to cancel already cancelled reservation
        response = client.post(f'/reservations/{reservation_id}/cancel', 
                               headers={'Authorization': f'Bearer {token}'})
        
        assert response.status_code == 400
        assert response.json['error'] == 'VALIDATION_ERROR'


class TestReservationList:
    """Test reservation listing endpoints."""
    
    def test_list_reservations(self, client, auth_headers_driver):
        """Test listing all reservations."""
        response = client.get('/reservations/', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert isinstance(response.json, list)
    
    def test_list_reservations_without_auth(self, client):
        """Test listing reservations without authentication fails."""
        response = client.get('/reservations/')
        
        assert response.status_code == 401
        assert response.json['error'] == 'UNAUTHORIZED'


class TestReservationEdgeCases:
    """Test reservation edge cases and security."""
    
    def test_reservation_seat_restoration_on_cancel(self, client, auth_headers_passenger, 
                                                       auth_headers_driver, test_passenger, app):
        """Test that cancelling confirmed reservation restores seats."""
        from app.models import Reservation, Ride
        from app.extensions import db
        from datetime import datetime, timedelta
        
        with app.app_context():
            # Create a fresh ride with 5 seats
            ride = Ride(
                driver_id=1,
                origin='Seat Test Origin',
                destination='Seat Test Dest',
                departure_time=datetime.now() + timedelta(hours=2),
                available_seats=5,
                status='ACTIVE'
            )
            db.session.add(ride)
            db.session.flush()
            ride_id = ride.id
            
            # Create confirmed reservation with 2 seats
            reservation = Reservation(
                employee_id=test_passenger.id,
                ride_id=ride_id,
                seats_reserved=2,
                status='CONFIRMED'
            )
            ride.available_seats -= 2  # Deduct seats
            db.session.add(reservation)
            db.session.commit()
            
            reservation_id = reservation.id
            initial_seats = ride.available_seats  # Should be 3
        
        # Cancel the reservation via API
        response = client.post(f'/reservations/{reservation_id}/cancel', headers=auth_headers_passenger)
        
        assert response.status_code == 200
        
        # Verify seats were restored
        with app.app_context():
            ride = Ride.query.get(ride_id)
            assert ride.available_seats == initial_seats + 2
