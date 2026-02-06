"""Notifications endpoint tests.

Tests notification creation, listing, and marking as read.
"""
import pytest


class TestNotificationList:
    """Test notification listing endpoints."""
    
    def test_list_notifications(self, client, auth_headers_driver, test_driver, app):
        """Test listing notifications for an employee."""
        from app.models import Notification
        from app.extensions import db
        
        # Create a notification
        with app.app_context():
            notification = Notification(
                employee_id=test_driver.id,
                ride_id=1,
                message='Test notification',
                is_read=False
            )
            db.session.add(notification)
            db.session.commit()
        
        response = client.get(f'/notifications/{test_driver.id}', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert isinstance(response.json, list)
    
    def test_list_notifications_without_auth(self, client, test_driver):
        """Test listing notifications without authentication fails."""
        response = client.get(f'/notifications/{test_driver.id}')
        
        assert response.status_code == 401
        assert response.json['error'] == 'UNAUTHORIZED'


class TestNotificationCreate:
    """Test notification creation endpoints."""
    
    def test_create_notification_success(self, client, auth_headers_driver, test_passenger):
        """Test creating a custom notification."""
        response = client.post('/notifications/', headers=auth_headers_driver, json={
            'employee_id': test_passenger.id,
            'message': 'Custom test notification',
            'ride_id': 1
        })
        
        assert response.status_code == 201
        assert response.json['message'] == 'Custom test notification'
        assert response.json['is_read'] == False
    
    def test_create_notification_missing_employee(self, client, auth_headers_driver):
        """Test creating notification without employee_id fails."""
        response = client.post('/notifications/', headers=auth_headers_driver, json={
            'message': 'Test notification'
        })
        
        assert response.status_code == 400
        assert response.json['error'] == 'VALIDATION_ERROR'


class TestNotificationRead:
    """Test notification marking as read."""
    
    def test_mark_notification_read(self, client, auth_headers_driver, test_driver, app):
        """Test marking a notification as read."""
        from app.models import Notification
        from app.extensions import db
        
        # Create a notification
        with app.app_context():
            notification = Notification(
                employee_id=test_driver.id,
                ride_id=1,
                message='Test notification',
                is_read=False
            )
            db.session.add(notification)
            db.session.commit()
            notification_id = notification.id
        
        response = client.patch(f'/notifications/{notification_id}/read', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert response.json['is_read'] == True
    
    def test_mark_nonexistent_notification(self, client, auth_headers_driver):
        """Test marking non-existent notification returns 404."""
        response = client.patch('/notifications/99999/read', headers=auth_headers_driver)
        
        assert response.status_code == 404
        assert response.json['error'] == 'NOT_FOUND'


class TestNotificationDelete:
    """Test notification deletion."""
    
    def test_delete_notification(self, client, auth_headers_driver, test_driver, app):
        """Test deleting a notification."""
        from app.models import Notification
        from app.extensions import db
        
        # Create a notification
        with app.app_context():
            notification = Notification(
                employee_id=test_driver.id,
                ride_id=1,
                message='Test notification to delete',
                is_read=False
            )
            db.session.add(notification)
            db.session.commit()
            notification_id = notification.id
        
        response = client.delete(f'/notifications/{notification_id}', headers=auth_headers_driver)
        
        assert response.status_code == 200
        assert 'deleted successfully' in response.json['message']
