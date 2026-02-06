from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required

from app.extensions import db
from app.models import Notification

api = Namespace('notifications', description='Notification operations')

# Error response model
error_response = api.model('ErrorResponse', {
    'error': fields.String(description='Error code (e.g., VALIDATION_ERROR, NOT_FOUND, UNAUTHORIZED, FORBIDDEN, INTERNAL_ERROR)'),
    'message': fields.String(description='Human readable error message')
})

notification_create = api.model('NotificationCreate', {
    'employee_id': fields.Integer(required=True, description='Employee ID to notify'),
    'ride_id': fields.Integer(required=False, description='Related ride ID (optional)'),
    'message': fields.String(required=True, description='Notification message content')
})

notification_response = api.model('NotificationResponse', {
    'id': fields.Integer(description='Notification ID'),
    'employee_id': fields.Integer(description='Employee ID'),
    'ride_id': fields.Integer(description='Ride ID'),
    'message': fields.String(description='Notification message'),
    'is_read': fields.Boolean(description='Read status'),
    'created_at': fields.DateTime(description='Creation timestamp')
})

notification_read_response = api.model('NotificationReadResponse', {
    'id': fields.Integer(description='Notification ID'),
    'message': fields.String(description='Notification message'),
    'is_read': fields.Boolean(description='Read status')
})


@api.route('/')
class NotificationCreate(Resource):
    @jwt_required()
    @api.doc('create_notification', security='Bearer', description='Create a custom notification for an employee',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.expect(notification_create)
    @api.marshal_with(notification_response)
    def post(self):
        """Create a custom notification"""
        data = request.get_json() or {}
        
        employee_id = data.get('employee_id')
        message = data.get('message')
        ride_id = data.get('ride_id')
        
        if not employee_id or not message:
            api.abort(400, 'employee_id and message are required')
        
        notification = Notification(
            employee_id=employee_id,
            ride_id=ride_id,
            message=message,
            is_read=False
        )
        db.session.add(notification)
        db.session.commit()
        
        return notification, 201


@api.route('/<int:employee_id>')
@api.param('employee_id', 'Employee ID')
class NotificationList(Resource):
    @jwt_required()
    @api.doc('list_notifications', security='Bearer',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_list_with(notification_response)
    def get(self, employee_id):
        """List all notifications for an employee (newest first)"""
        notifications = Notification.query.filter_by(employee_id=employee_id) \
            .order_by(Notification.created_at.desc()).all()
        return notifications


@api.route('/<int:notification_id>/read')
@api.param('notification_id', 'Notification ID')
class NotificationRead(Resource):
    @jwt_required()
    @api.doc('mark_notification_read', security='Bearer',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Not authorized', error_response),
            404: ('Notification not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(notification_read_response)
    def patch(self, notification_id):
        """Mark a notification as read"""
        from flask_jwt_extended import get_jwt_identity
        
        employee_id = int(get_jwt_identity())
        notification = Notification.query.get(notification_id)
        
        if not notification:
            api.abort(404, 'Notification not found')
        
        # Only the owner can mark their notification as read
        if notification.employee_id != employee_id:
            api.abort(403, 'Not authorized to access this notification')
        
        notification.is_read = True
        db.session.commit()
        return notification


@api.route('/<int:notification_id>')
@api.param('notification_id', 'Notification ID')
class NotificationDetail(Resource):
    @jwt_required()
    @api.doc('delete_notification', security='Bearer', description='Delete a notification by ID',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            404: ('Notification not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def delete(self, notification_id):
        """Delete a notification by ID"""
        notification = Notification.query.get(notification_id)
        if not notification:
            api.abort(404, 'Notification not found')
        db.session.delete(notification)
        db.session.commit()
        return {'message': 'Notification deleted successfully'}, 200
