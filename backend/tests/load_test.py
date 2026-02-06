"""Load testing using Locust.

Simulates multiple users interacting with the carpooling API.

Usage:
    locust -f tests/load_test.py --host=http://127.0.0.1:5000
    
Then open http://localhost:8089 in browser to start the test.

Requirements:
    pip install locust
"""
from locust import HttpUser, task, between
import random


class BaseUser(HttpUser):
    """Base user class with common functionality."""
    
    wait_time = between(1, 3)
    
    def on_start(self):
        """Called when a user starts."""
        self.token = None
        self.employee_id = None
        self.ride_id = None


class DriverUser(BaseUser):
    """Simulates a driver user creating rides and managing reservations."""
    
    weight = 1
    
    def on_start(self):
        """Register and login as driver."""
        # Generate unique email
        import uuid
        unique_id = str(uuid.uuid4())[:8]
        self.email = f"driver_{unique_id}@test.com"
        self.password = "testpass123"
        
        # Register
        response = self.client.post('/auth/register', json={
            'name': f'Test Driver {unique_id}',
            'email': self.email,
            'password': self.password,
            'department': 'Engineering'
        })
        
        # Login
        if response.status_code in [201, 409]:  # Created or already exists
            response = self.client.post('/auth/login', json={
                'email': self.email,
                'password': self.password
            })
            if response.status_code == 200:
                self.token = response.json()['access_token']
                self.employee_id = response.json()['employee']['id']
    
    @task(3)
    def create_ride(self):
        """Create a new ride."""
        if not self.token:
            return
        
        from datetime import datetime, timedelta
        departure_time = (datetime.now() + timedelta(hours=random.randint(1, 48))).isoformat()
        
        response = self.client.post('/rides/', 
            headers={'Authorization': f'Bearer {self.token}'},
            json={
                'driver_id': self.employee_id,
                'origin': random.choice(['Downtown', 'Airport', 'Suburbs', 'City Center']),
                'destination': random.choice(['Downtown', 'Airport', 'Suburbs', 'City Center']),
                'departure_time': departure_time,
                'available_seats': random.randint(1, 4)
            }
        )
        
        if response.status_code == 201:
            self.ride_id = response.json()['id']
    
    @task(2)
    def list_my_rides(self):
        """List rides where user is driver."""
        if not self.token:
            return
            
        self.client.get('/employees/me/rides',
            headers={'Authorization': f'Bearer {self.token}'}
        )
    
    @task(2)
    def view_participants(self):
        """View participants for a ride."""
        if not self.token or not self.ride_id:
            return
            
        self.client.get(f'/rides/{self.ride_id}/participants',
            headers={'Authorization': f'Bearer {self.token}'}
        )
    
    @task(1)
    def approve_reservation(self):
        """Approve a pending reservation."""
        if not self.token:
            return
        
        # Get pending reservations for rides this driver owns
        # This would need to be implemented based on your API
        pass


class PassengerUser(BaseUser):
    """Simulates a passenger searching and booking rides."""
    
    weight = 3
    
    def on_start(self):
        """Register and login as passenger."""
        import uuid
        unique_id = str(uuid.uuid4())[:8]
        self.email = f"passenger_{unique_id}@test.com"
        self.password = "testpass123"
        
        # Register
        response = self.client.post('/auth/register', json={
            'name': f'Test Passenger {unique_id}',
            'email': self.email,
            'password': self.password,
            'department': 'Sales'
        })
        
        # Login
        if response.status_code in [201, 409]:
            response = self.client.post('/auth/login', json={
                'email': self.email,
                'password': self.password
            })
            if response.status_code == 200:
                self.token = response.json()['access_token']
                self.employee_id = response.json()['employee']['id']
    
    @task(5)
    def search_rides(self):
        """Search for available rides."""
        if not self.token:
            return
        
        origins = ['Downtown', 'Airport', 'Suburbs', 'City Center', '']
        destinations = ['Downtown', 'Airport', 'Suburbs', 'City Center', '']
        
        params = {
            'origin': random.choice(origins),
            'destination': random.choice(destinations),
            'page': 1,
            'per_page': 10
        }
        
        self.client.get('/rides/',
            headers={'Authorization': f'Bearer {self.token}'},
            params=params
        )
    
    @task(3)
    def create_reservation(self):
        """Create a reservation for a ride."""
        if not self.token:
            return
        
        # First search for rides
        response = self.client.get('/rides/',
            headers={'Authorization': f'Bearer {self.token}'},
            params={'page': 1, 'per_page': 5}
        )
        
        if response.status_code == 200 and response.json()['items']:
            # Pick a random ride
            ride = random.choice(response.json()['items'])
            ride_id = ride['id']
            
            # Create reservation
            self.client.post('/reservations/',
                headers={'Authorization': f'Bearer {self.token}'},
                json={
                    'employee_id': self.employee_id,
                    'ride_id': ride_id,
                    'seats_reserved': random.randint(1, 2)
                }
            )
    
    @task(2)
    def view_my_reservations(self):
        """List my reservations."""
        if not self.token:
            return
            
        self.client.get('/employees/me/reservations',
            headers={'Authorization': f'Bearer {self.token}'}
        )
    
    @task(1)
    def check_notifications(self):
        """Check notifications."""
        if not self.token:
            return
            
        self.client.get(f'/notifications/{self.employee_id}',
            headers={'Authorization': f'Bearer {self.token}'}
        )
    
    @task(1)
    def view_profile(self):
        """View my profile."""
        if not self.token:
            return
            
        self.client.get('/auth/me',
            headers={'Authorization': f'Bearer {self.token}'}
        )


class AdminUser(BaseUser):
    """Simulates admin viewing statistics."""
    
    weight = 1
    
    def on_start(self):
        """Login as admin (using first available user)."""
        self.email = "admin@example.com"
        self.password = "admin123"
        self.token = None
    
    @task(5)
    def view_stats(self):
        """View admin statistics."""
        if not self.token:
            return
            
        self.client.get('/admin/stats',
            headers={'Authorization': f'Bearer {self.token}'}
        )
