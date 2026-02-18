from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy import func

from app.extensions import db
from app.models import Employee, Ride, Reservation

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

admin_stats_response = api.model('AdminStatsResponse', {
    'total_employees': fields.Integer(description='Total number of employees'),
    'total_rides': fields.Integer(description='Total number of rides'),
    'active_rides': fields.Integer(description='Rides with status ACTIVE or FULL'),
    'completed_rides': fields.Integer(description='Rides with status COMPLETED'),
    'total_reservations': fields.Integer(description='Total number of reservations'),
    'cancelled_reservations': fields.Integer(description='Reservations with status CANCELLED'),
    'average_occupancy_rate': fields.Float(description='Percentage of seats filled across all rides')
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
    @api.marshal_with(admin_stats_response)
    def get(self):
        """Get aggregated platform statistics"""
        # Total counts
        total_employees = Employee.query.count()
        total_rides = Ride.query.count()
        total_reservations = Reservation.query.count()
        
        # Ride status counts
        active_rides = Ride.query.filter(Ride.status.in_(['ACTIVE', 'FULL'])).count()
        completed_rides = Ride.query.filter_by(status='COMPLETED').count()
        
        # Reservation status counts
        cancelled_reservations = Reservation.query.filter_by(status='CANCELLED').count()
        
        # Calculate average occupancy rate
        # Get total capacity and total reserved seats
        rides_with_capacity = db.session.query(
            func.sum(Ride.available_seats).label('total_available'),
            func.count(Ride.id).label('ride_count')
        ).filter(Ride.status != 'COMPLETED').first()
        
        total_reserved = db.session.query(
            func.sum(Reservation.seats_reserved)
        ).filter(Reservation.status == 'CONFIRMED').scalar() or 0
        
        # Calculate occupancy: reserved / (available + reserved) * 100
        total_available = rides_with_capacity.total_available or 0
        total_capacity = total_available + total_reserved
        
        if total_capacity > 0:
            average_occupancy_rate = round((total_reserved / total_capacity) * 100, 2)
        else:
            average_occupancy_rate = 0.0
        
        return {
            'total_employees': total_employees,
            'total_rides': total_rides,
            'active_rides': active_rides,
            'completed_rides': completed_rides,
            'total_reservations': total_reservations,
            'cancelled_reservations': cancelled_reservations,
            'average_occupancy_rate': average_occupancy_rate
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
