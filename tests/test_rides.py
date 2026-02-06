"""Rides endpoint tests.

Tests ride creation, listing, updating, and deletion.
"""
import pytest
from datetime import datetime, timedelta


class TestRideList:
    """Test ride listing and search endpoints."""
    
    def test_list_rides_success(self, client, auth_headers_driver):
        """Test listing all rides returns paginated results."""
        response = client.get('/rides/', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert 'items' in response.json
        assert 'page' in response.json
        assert 'total_items' in response.json
    
    def test_list_rides_with_filters(self, client, auth_headers_driver, sample_ride):
        """Test filtering rides by origin."""
        response = client.get('/rides/?origin=Downtown', headers=auth_headers_driver)
        
        assert response.status_code == 200
        # Should find the sample ride
        if response.json['items']:
            assert response.json['items'][0]['origin'] == 'Downtown'
    
    def test_list_rides_pagination(self, client, auth_headers_driver):
        """Test ride pagination parameters."""
        response = client.get('/rides/?page=1&per_page=5', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert response.json['page'] == 1
        assert response.json['per_page'] == 5
    
    def test_list_rides_invalid_page(self, client, auth_headers_driver):
        """Test invalid page parameter returns error."""
        response = client.get('/rides/?page=0', headers=auth_headers_driver)
        
        assert response.status_code == 400
        assert response.json['error'] == 'VALIDATION_ERROR'


class TestRideCreate:
    """Test ride creation endpoints."""
    
    def test_create_ride_success(self, client, auth_headers_driver, test_driver):
        """Test creating a new ride."""
        departure_time = (datetime.now() + timedelta(days=1)).isoformat()
        
        response = client.post('/rides/', headers=auth_headers_driver, json={
            'driver_id': test_driver.id,
            'origin': 'City Center',
            'destination': 'Suburbs',
            'departure_time': departure_time,
            'available_seats': 3
        })
        
        assert response.status_code == 201
        assert response.json['origin'] == 'City Center'
        assert response.json['destination'] == 'Suburbs'
        assert response.json['available_seats'] == 3
        assert response.json['status'] == 'ACTIVE'
    
    def test_create_ride_invalid_seats(self, client, auth_headers_driver, test_driver):
        """Test creating ride with invalid seats fails."""
        departure_time = (datetime.now() + timedelta(days=1)).isoformat()
        
        response = client.post('/rides/', headers=auth_headers_driver, json={
            'driver_id': test_driver.id,
            'origin': 'City Center',
            'destination': 'Suburbs',
            'departure_time': departure_time,
            'available_seats': 0  # Invalid
        })
        
        assert response.status_code == 400
        assert response.json['error'] == 'VALIDATION_ERROR'
    
    def test_create_ride_missing_fields(self, client, auth_headers_driver):
        """Test creating ride with missing fields fails."""
        response = client.post('/rides/', headers=auth_headers_driver, json={
            'origin': 'City Center'
            # Missing other required fields
        })
        
        assert response.status_code == 400
        assert 'error' in response.json


class TestRideDetail:
    """Test ride detail, update, and delete endpoints."""
    
    def test_get_ride_success(self, client, auth_headers_driver, sample_ride):
        """Test getting a single ride by ID."""
        response = client.get(f'/rides/{sample_ride.id}', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert response.json['id'] == sample_ride.id
        assert response.json['origin'] == sample_ride.origin
    
    def test_get_nonexistent_ride(self, client, auth_headers_driver):
        """Test getting non-existent ride returns 404."""
        response = client.get('/rides/99999', headers=auth_headers_driver)
        
        assert response.status_code == 404
        assert response.json['error'] == 'NOT_FOUND'
    
    def test_update_ride_success(self, client, auth_headers_driver, sample_ride):
        """Test updating ride details."""
        response = client.put(f'/rides/{sample_ride.id}', headers=auth_headers_driver, json={
            'origin': 'Updated Origin',
            'available_seats': 5
        })
        
        assert response.status_code == 200
        assert response.json['origin'] == 'Updated Origin'
        assert response.json['available_seats'] == 5
    
    def test_update_ride_unauthorized(self, client, auth_headers_passenger, sample_ride):
        """Test passenger cannot update driver's ride."""
        response = client.put(f'/rides/{sample_ride.id}', headers=auth_headers_passenger, json={
            'origin': 'Hacked Origin'
        })
        
        assert response.status_code == 403
        assert response.json['error'] == 'FORBIDDEN'
    
    def test_delete_ride_success(self, client, auth_headers_driver, app, test_driver):
        """Test deleting a ride."""
        # Create a ride to delete
        from app.models import Ride
        with app.app_context():
            ride = Ride(
                driver_id=test_driver.id,
                origin='Temp Origin',
                destination='Temp Destination',
                departure_time=datetime.now() + timedelta(days=1),
                available_seats=2
            )
            from app.extensions import db
            db.session.add(ride)
            db.session.commit()
            ride_id = ride.id
        
        response = client.delete(f'/rides/{ride_id}', headers=auth_headers_driver)
        assert response.status_code == 200


class TestRideComplete:
    """Test ride completion endpoint."""
    
    def test_complete_ride_success(self, client, auth_headers_driver, sample_ride):
        """Test driver can mark ride as completed."""
        response = client.patch(f'/rides/{sample_ride.id}/complete', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert response.json['status'] == 'COMPLETED'
    
    def test_complete_ride_unauthorized(self, client, auth_headers_passenger, sample_ride):
        """Test passenger cannot complete driver's ride."""
        response = client.patch(f'/rides/{sample_ride.id}/complete', headers=auth_headers_passenger)
        
        assert response.status_code == 403
        assert response.json['error'] == 'FORBIDDEN'
    
    def test_complete_already_completed_ride(self, client, auth_headers_driver, sample_ride):
        """Test completing already completed ride returns error."""
        # First complete the ride
        client.patch(f'/rides/{sample_ride.id}/complete', headers=auth_headers_driver)
        
        # Try to complete again
        response = client.patch(f'/rides/{sample_ride.id}/complete', headers=auth_headers_driver)
        
        assert response.status_code == 400
        assert response.json['error'] == 'VALIDATION_ERROR'


class TestRideParticipants:
    """Test ride participants endpoint."""
    
    def test_get_participants_as_driver(self, client, auth_headers_driver, sample_ride, confirmed_reservation):
        """Test driver can view ride participants."""
        response = client.get(f'/rides/{sample_ride.id}/participants', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert isinstance(response.json, list)
    
    def test_get_participants_as_passenger_forbidden(self, client, auth_headers_passenger, sample_ride):
        """Test passenger cannot view participants."""
        response = client.get(f'/rides/{sample_ride.id}/participants', headers=auth_headers_passenger)
        
        assert response.status_code == 403
        assert response.json['error'] == 'FORBIDDEN'
