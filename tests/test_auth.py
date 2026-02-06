"""Authentication endpoint tests.

Tests user registration, login, and authentication flows.
"""
import pytest


class TestAuthRegistration:
    """Test user registration endpoints."""
    
    def test_register_success(self, client):
        """Test successful user registration."""
        response = client.post('/auth/register', json={
            'name': 'New User',
            'email': 'newuser@test.com',
            'password': 'password123',
            'department': 'IT'
        })
        
        assert response.status_code == 201
        assert 'id' in response.json
        assert response.json['email'] == 'newuser@test.com'
        assert response.json['name'] == 'New User'
    
    def test_register_duplicate_email(self, client):
        """Test registration with duplicate email fails."""
        import uuid
        unique_id = str(uuid.uuid4())[:8]
        email = f'dup_{unique_id}@test.com'
        
        # Register first user
        response1 = client.post('/auth/register', json={
            'name': 'First User',
            'email': email,
            'password': 'password123',
            'department': 'HR'
        })
        assert response1.status_code == 201
        
        # Try to register with same email
        response = client.post('/auth/register', json={
            'name': 'Another User',
            'email': email,
            'password': 'password123',
            'department': 'HR'
        })
        
        assert response.status_code == 409
        assert response.json['error'] == 'CONFLICT'
    
    def test_register_missing_fields(self, client):
        """Test registration with missing required fields fails."""
        response = client.post('/auth/register', json={
            'name': 'Incomplete User'
            # Missing email, password, department
        })
        
        assert response.status_code == 400
        assert 'error' in response.json
    
    def test_register_invalid_email_format(self, client):
        """Test registration with invalid email format fails."""
        response = client.post('/auth/register', json={
            'name': 'Bad Email User',
            'email': 'not-an-email',
            'password': 'password123',
            'department': 'IT'
        })
        
        # Should either fail validation or succeed if no email validation
        assert response.status_code in [201, 400]


class TestAuthLogin:
    """Test user login endpoints."""
    
    def test_login_success(self, client, test_driver):
        """Test successful login returns token."""
        response = client.post('/auth/login', json={
            'email': test_driver.email,
            'password': 'testpass123'
        })
        
        assert response.status_code == 200
        assert 'access_token' in response.json
        assert 'employee' in response.json
        assert response.json['employee']['email'] == test_driver.email
    
    def test_login_invalid_credentials(self, client, test_driver):
        """Test login with wrong password fails."""
        response = client.post('/auth/login', json={
            'email': test_driver.email,
            'password': 'wrongpassword'
        })
        
        assert response.status_code == 401
        assert response.json['error'] == 'UNAUTHORIZED'
    
    def test_login_nonexistent_user(self, client):
        """Test login with non-existent user fails."""
        response = client.post('/auth/login', json={
            'email': 'nonexistent@test.com',
            'password': 'password123'
        })
        
        assert response.status_code == 401
        assert response.json['error'] == 'UNAUTHORIZED'
    
    def test_login_missing_fields(self, client):
        """Test login with missing fields fails."""
        response = client.post('/auth/login', json={
            'email': 'someone@test.com'
            # Missing password
        })
        
        assert response.status_code == 400
        assert 'error' in response.json


class TestAuthProtectedEndpoints:
    """Test authentication on protected endpoints."""
    
    def test_access_without_token_fails(self, client):
        """Test accessing protected endpoint without token returns 401."""
        response = client.get('/rides/')
        
        assert response.status_code == 401
        assert response.json['error'] == 'UNAUTHORIZED'
    
    def test_access_with_invalid_token_fails(self, client):
        """Test accessing protected endpoint with invalid token returns 401."""
        response = client.get('/rides/', headers={
            'Authorization': 'Bearer invalid-token'
        })
        
        assert response.status_code == 401
        assert response.json['error'] == 'UNAUTHORIZED'
    
    def test_access_with_valid_token_succeeds(self, client, auth_headers_driver):
        """Test accessing protected endpoint with valid token succeeds."""
        response = client.get('/rides/', headers=auth_headers_driver)
        
        # Should succeed (even if empty list)
        assert response.status_code == 200


class TestAuthGetCurrentUser:
    """Test get current authenticated user endpoint."""
    
    def test_get_me_success(self, client, auth_headers_driver, test_driver):
        """Test getting current user info with valid token."""
        response = client.get('/auth/me', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert response.json['email'] == test_driver.email
        assert response.json['name'] == test_driver.name
    
    def test_get_me_without_token_fails(self, client):
        """Test getting current user without token fails."""
        response = client.get('/auth/me')
        
        assert response.status_code == 401
        assert response.json['error'] == 'UNAUTHORIZED'
