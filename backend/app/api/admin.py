from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity

from app.extensions import db
from app.models import Employee, Ride, Reservation
from app.services.system_metrics_service import (
    get_total_users,
    get_active_rides as get_service_active_rides,
    get_total_rides,
    get_total_reservations,
)

api = Namespace('admin', description='Admin operations and statistics')

# Error response model
error_response = api.model('ErrorResponse', {
    'error': fields.String(description='Error code (e.g., VALIDATION_ERROR, NOT_FOUND, UNAUTHORIZED, FORBIDDEN, INTERNAL_ERROR)'),
    'message': fields.String(description='Human readable error message')
})

# User management models
user_response = api.model('UserResponse', {
    'id': fields.Integer(description='User ID'),
    'name': fields.String(description='Full name'),
    'email': fields.String(description='Email address'),
    'status': fields.String(description='User status (active, frozen, suspended)'),
    'role': fields.String(description='User role (employee, admin)'),
    'department': fields.String(description='Department')
})

toggle_status_request = api.model('ToggleStatusRequest', {
    'status': fields.String(required=True, description='New status (active or frozen)', enum=['active', 'frozen'])
})

toggle_status_response = api.model('ToggleStatusResponse', {
    'id': fields.Integer(description='User ID'),
    'name': fields.String(description='Full name'),
    'email': fields.String(description='Email address'),
    'status': fields.String(description='Updated status'),
    'role': fields.String(description='User role')
})

def require_admin():
    """Helper function to verify current user is admin"""
    current_user_id = get_jwt_identity()
    current_user = Employee.query.get(current_user_id)
    if not current_user or current_user.role != 'admin':
        return {'error': 'FORBIDDEN', 'message': 'Admin access required'}, 403
    return current_user

# Dashboard stats response model
dashboard_stats_response = api.model('DashboardStatsResponse', {
    'total_users': fields.Integer(description='Total number of users/employees'),
    'active_users': fields.Integer(description='Count of active users'),
    'total_rides': fields.Integer(description='Total number of rides'),
    'total_reservations': fields.Integer(description='Total number of reservations'),
    'co2_saved_kg': fields.Integer(description='Estimated CO2 saved in kg (reservations * 2.5)')
})


@api.route('/stats')
class AdminStats(Resource):
    @jwt_required()
    @api.doc('get_stats', security='Bearer', description='Get platform statistics and metrics',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(dashboard_stats_response)
    def get(self):
        """Get aggregated platform statistics for dashboard"""
        # Verify admin access
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        # Use shared metrics service for consistency
        total_users = get_total_users()
        active_rides = get_service_active_rides()
        total_rides = get_total_rides()
        total_reservations = get_total_reservations()
        
        # Calculate CO2 saved: each reservation saves ~2.5kg
        co2_saved_kg = int(total_reservations * 2.5)
        
        return {
            'total_users': total_users,
            'active_users': active_rides,  # Using active_rides as active_users for consistency
            'total_rides': total_rides,
            'total_reservations': total_reservations,
            'co2_saved_kg': co2_saved_kg
        }


@api.route('/users')
class AdminUsersList(Resource):
    @jwt_required()
    @api.doc('get_users', security='Bearer', description='Get all employees (Admin only, excludes other admins)',
        responses={
            200: ('List of all employees', [user_response]),
            403: ('Forbidden - Admin access required', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    @api.marshal_list_with(user_response)
    def get(self):
        """Get all employees list (excludes admins)"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        current_user_id = get_jwt_identity()
        
        # Only return employees (role='employee'), exclude all admins including current user
        employees = Employee.query.filter(
            Employee.role == 'employee',
            Employee.id != current_user_id
        ).all()
        
        return [emp.to_dict() for emp in employees]


@api.route('/users/<int:id>/status')
class AdminUserStatus(Resource):
    @jwt_required()
    @api.doc('toggle_user_status', security='Bearer', description='Toggle user status (Admin only)',
        responses={
            200: ('User status updated', toggle_status_response),
            400: ('Invalid status value', error_response),
            403: ('Forbidden - Admin access required', error_response),
            404: ('User not found', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    @api.expect(toggle_status_request)
    @api.marshal_with(toggle_status_response)
    def put(self, id):
        """Toggle user active/frozen status"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        data = api.payload
        if not data or 'status' not in data:
            return {'error': 'VALIDATION_ERROR', 'message': 'Status is required'}, 400
        
        new_status = data['status']
        if new_status not in ['active', 'frozen']:
            return {'error': 'VALIDATION_ERROR', 'message': 'Status must be active or frozen'}, 400
        
        user = Employee.query.get(id)
        if not user:
            return {'error': 'NOT_FOUND', 'message': 'User not found'}, 404
        
        user.status = new_status
        db.session.commit()
        
        return user.to_dict()
