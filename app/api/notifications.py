from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required

from app.extensions import db
from app.models import Notification

api = Namespace('notifications', description='Notification operations')

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


@api.route('/<int:employee_id>')
@api.param('employee_id', 'Employee ID')
class NotificationList(Resource):
    @jwt_required()
    @api.doc('list_notifications', security='Bearer')
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
    @api.doc('mark_notification_read', security='Bearer')
    @api.marshal_with(notification_read_response)
    def patch(self, notification_id):
        """Mark a notification as read"""
        notification = Notification.query.get(notification_id)
        if not notification:
            api.abort(404, 'Notification not found')

        notification.is_read = True
        db.session.commit()
        return notification


@api.route('/<int:notification_id>')
@api.param('notification_id', 'Notification ID')
class NotificationDetail(Resource):
    @jwt_required()
    @api.doc('delete_notification', security='Bearer', description='Delete a notification by ID')
    def delete(self, notification_id):
        """Delete a notification by ID"""
        notification = Notification.query.get(notification_id)
        if not notification:
            api.abort(404, 'Notification not found')
        db.session.delete(notification)
        db.session.commit()
        return {'message': 'Notification deleted successfully'}, 200
