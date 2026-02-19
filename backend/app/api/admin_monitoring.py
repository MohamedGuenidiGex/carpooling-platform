"""Admin Monitoring API - Real-time system monitoring endpoints."""

from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models import Employee
from app.services.admin_monitoring_service import (
    get_monitoring_overview,
    update_last_seen
)

api = Namespace('admin/monitoring', description='Admin real-time monitoring endpoints')

# Response models
system_health_model = api.model('SystemHealth', {
    'status': fields.String(description='System status (operational/degraded/unknown)'),
    'message': fields.String(description='Human readable status message'),
    'last_updated': fields.String(description='ISO timestamp of last status update')
})

live_metrics_model = api.model('LiveMetrics', {
    'active_rides_now': fields.Integer(description='Currently active rides'),
    'online_users': fields.Integer(description='Users active in last 10 minutes'),
    'pending_requests': fields.Integer(description='Pending reservation requests'),
    'active_sessions': fields.Integer(description='Active sessions (last 30 min)')
})

event_model = api.model('SystemEvent', {
    'id': fields.Integer(description='Event ID'),
    'event_type': fields.String(description='Type of event'),
    'message': fields.String(description='Event description'),
    'severity': fields.String(description='Event severity (info/warning/critical)'),
    'employee': fields.String(description='Related employee name (if any)'),
    'employee_id': fields.Integer(description='Related employee ID'),
    'ride_id': fields.Integer(description='Related ride ID'),
    'reservation_id': fields.Integer(description='Related reservation ID'),
    'created_at': fields.String(description='ISO timestamp')
})

monitoring_overview_model = api.model('MonitoringOverview', {
    'system_health': fields.Nested(system_health_model),
    'live_metrics': fields.Nested(live_metrics_model),
    'recent_events': fields.List(fields.Nested(event_model))
})

error_response = api.model('ErrorResponse', {
    'error': fields.String(description='Error code'),
    'message': fields.String(description='Error message')
})


def require_admin():
    """Verify current user is admin."""
    current_user_id = get_jwt_identity()
    employee = Employee.query.get(current_user_id)

    if not employee:
        return {'error': 'NOT_FOUND', 'message': 'User not found'}, 404

    if employee.role != 'admin':
        return {'error': 'FORBIDDEN', 'message': 'Admin access required'}, 403

    return employee


@api.route('/overview')
class MonitoringOverview(Resource):
    @jwt_required()
    @api.doc(
        'get_monitoring_overview',
        security='Bearer',
        description='Get real-time monitoring overview for admin dashboard',
        responses={
            200: ('Monitoring overview', monitoring_overview_model),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Admin access required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(monitoring_overview_model)
    def get(self):
        """Get real-time monitoring overview."""
        result = require_admin()
        if isinstance(result, tuple):
            return result

        # Update the admin's last seen time
        update_last_seen(result.id)

        return get_monitoring_overview()


@api.route('/heartbeat')
class Heartbeat(Resource):
    @jwt_required()
    @api.doc(
        'heartbeat',
        security='Bearer',
        description='Update user activity timestamp (call periodically to show online)',
        responses={
            200: ('Heartbeat recorded', {'success': fields.Boolean}),
            401: ('Unauthorized - JWT required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def post(self):
        """Record user heartbeat to update last_seen timestamp."""
        current_user_id = get_jwt_identity()
        update_last_seen(current_user_id)
        return {'success': True}
