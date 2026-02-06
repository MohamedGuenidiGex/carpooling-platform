"""Edge case and security tests.

Tests for boundary conditions, security scenarios, and robustness.
"""
import pytest
from datetime import datetime, timedelta


class TestEdgeCases:
    """Test edge cases and boundary conditions."""
    
    def test_create_ride_with_maximum_seats(self, client, auth_headers_driver, test_driver):
        """Test creating ride with maximum allowed seats."""
        departure_time = (datetime.now() + timedelta(days=1)).isoformat()
        
        response = client.post('/rides/', headers=auth_headers_driver, json={
            'driver_id': test_driver.id,
            'origin': 'Origin',
            'destination': 'Destination',
            'departure_time': departure_time,
            'available_seats': 50  # Maximum reasonable value
        })
        
        assert response.status_code == 201
        assert response.json['available_seats'] == 50
    
    def test_pagination_with_large_page_number(self, client, auth_headers_driver):
        """Test pagination with large page number."""
        response = client.get('/rides/?page=1000&per_page=10', headers=auth_headers_driver)
        
        # Should return empty but valid response
        assert response.status_code == 200
        assert response.json['items'] == []
    
    def test_date_filters_with_past_dates(self, client, auth_headers_driver):
        """Test filtering rides with past dates."""
        past_date = (datetime.now() - timedelta(days=30)).isoformat()
        
        response = client.get(f'/rides/?date_from={past_date}', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert 'items' in response.json


class TestSecurity:
    """Test security scenarios and access control."""
    
    def test_sql_injection_attempt_in_search(self, client, auth_headers_driver):
        """Test that SQL injection attempts are handled safely."""
        # Attempt SQL injection in origin filter
        response = client.get('/rides/?origin=\'; DROP TABLE rides; --', headers=auth_headers_driver)
        
        # Should not crash or execute SQL
        assert response.status_code in [200, 400]
    
    def test_xss_attempt_in_ride_data(self, client, auth_headers_driver, test_driver):
        """Test XSS prevention in ride data."""
        departure_time = (datetime.now() + timedelta(days=1)).isoformat()
        
        xss_payload = '<script>alert("XSS")</script>'
        response = client.post('/rides/', headers=auth_headers_driver, json={
            'driver_id': test_driver.id,
            'origin': xss_payload,
            'destination': 'Safe Destination',
            'departure_time': departure_time,
            'available_seats': 2
        })
        
        # Should accept but ideally sanitize
        assert response.status_code == 201
    
    def test_expired_token_access(self, client, test_driver, app):
        """Test that expired tokens are rejected."""
        # Create an expired token manually
        from flask_jwt_extended import create_access_token
        
        with app.app_context():
            expired_token = create_access_token(
                identity=str(test_driver.id),
                expires_delta=timedelta(seconds=-1)  # Already expired
            )
        
        response = client.get('/rides/', headers={
            'Authorization': f'Bearer {expired_token}'
        })
        
        assert response.status_code == 401
        assert response.json['error'] == 'UNAUTHORIZED'
    
    def test_access_other_user_notifications(self, client, auth_headers_passenger, test_driver, app):
        """Test that users cannot access other users' notifications."""
        from app.models import Notification
        from app.extensions import db
        
        # Create notification for driver
        with app.app_context():
            notification = Notification(
                employee_id=test_driver.id,
                ride_id=1,
                message='Private notification',
                is_read=False
            )
            db.session.add(notification)
            db.session.commit()
            notification_id = notification.id
        
        # Passenger tries to read driver's notification
        response = client.patch(f'/notifications/{notification_id}/read', headers=auth_headers_passenger)
        
        # Should be rejected
        assert response.status_code == 403
    
    def test_modify_ride_as_non_driver(self, client, auth_headers_passenger, sample_ride):
        """Test that only driver can modify their ride."""
        response = client.put(f'/rides/{sample_ride.id}', headers=auth_headers_passenger, json={
            'origin': 'Hacked!',
            'available_seats': 1
        })
        
        assert response.status_code == 403
        assert response.json['error'] == 'FORBIDDEN'
    
    def test_mass_assignment_protection(self, client, auth_headers_driver, test_driver):
        """Test that mass assignment vulnerabilities are prevented."""
        departure_time = (datetime.now() + timedelta(days=1)).isoformat()
        
        # Try to set read-only fields
        response = client.post('/rides/', headers=auth_headers_driver, json={
            'driver_id': test_driver.id,
            'origin': 'Origin',
            'destination': 'Destination',
            'departure_time': departure_time,
            'available_seats': 2,
            'status': 'FULL',  # Should not be settable on creation
            'id': 99999  # Should not be settable
        })
        
        # Should either succeed with defaults or reject
        assert response.status_code in [201, 400]
        
        if response.status_code == 201:
            assert response.json['status'] == 'ACTIVE'  # Not FULL


class TestDataIntegrity:
    """Test data integrity and consistency."""
    
    def test_ride_seats_consistency_after_reservation(self, client, auth_headers_driver,
                                                        auth_headers_passenger, 
                                                        sample_ride, test_passenger, app):
        """Test that ride seats are correctly deducted after approval."""
        from app.models import Reservation
        from app.extensions import db
        
        initial_seats = sample_ride.available_seats
        
        # Create reservation
        with app.app_context():
            reservation = Reservation(
                employee_id=test_passenger.id,
                ride_id=sample_ride.id,
                seats_reserved=2,
                status='PENDING'
            )
            db.session.add(reservation)
            db.session.commit()
            reservation_id = reservation.id
        
        # Approve reservation
        response = client.patch(f'/reservations/{reservation_id}/approve', headers=auth_headers_driver)
        
        assert response.status_code == 200
        
        # Verify seats were deducted
        with app.app_context():
            from app.models import Ride
            ride = Ride.query.get(sample_ride.id)
            assert ride.available_seats == initial_seats - 2
    
    def test_cannot_approve_confirmed_reservation(self, client, auth_headers_driver, confirmed_reservation):
        """Test that confirmed reservations cannot be re-approved."""
        response = client.patch(f'/reservations/{confirmed_reservation.id}/approve', headers=auth_headers_driver)
        
        assert response.status_code == 400
        assert 'Cannot approve' in response.json['message']
    
    def test_cannot_book_full_ride(self, client, auth_headers_passenger, sample_ride, test_passenger, app):
        """Test that booking a full ride fails."""
        from app.extensions import db
        
        # Fill the ride
        with app.app_context():
            sample_ride.status = 'FULL'
            db.session.commit()
        
        response = client.post('/reservations/', headers=auth_headers_passenger, json={
            'employee_id': test_passenger.id,
            'ride_id': sample_ride.id,
            'seats_reserved': 1
        })
        
        assert response.status_code == 400
        assert 'full' in response.json['message'].lower()


class TestRateLimitingConsiderations:
    """Test considerations for rate limiting (documentation purposes)."""
    
    def test_rapid_successive_requests(self, client, auth_headers_driver):
        """Test handling of rapid successive requests."""
        # Make multiple rapid requests
        responses = []
        for _ in range(5):
            response = client.get('/rides/', headers=auth_headers_driver)
            responses.append(response.status_code)
        
        # All should succeed (or some may be rate limited in production)
        assert all(status == 200 for status in responses)
    
    def test_large_payload_handling(self, client, auth_headers_driver, test_driver):
        """Test handling of large request payloads."""
        departure_time = (datetime.now() + timedelta(days=1)).isoformat()
        
        # Create very long origin string
        long_origin = 'A' * 10000
        
        response = client.post('/rides/', headers=auth_headers_driver, json={
            'driver_id': test_driver.id,
            'origin': long_origin,
            'destination': 'Destination',
            'departure_time': departure_time,
            'available_seats': 2
        })
        
        # Should either accept or reject gracefully
        assert response.status_code in [201, 400, 413]  # Created, Bad Request, or Payload Too Large
