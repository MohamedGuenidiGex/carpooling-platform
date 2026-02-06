from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required
from sqlalchemy import func

from app.extensions import db
from app.models import Employee, Ride, Reservation

api = Namespace('admin', description='Admin operations and statistics')

# Error response model
error_response = api.model('ErrorResponse', {
    'error': fields.String(description='Error code (e.g., VALIDATION_ERROR, NOT_FOUND, UNAUTHORIZED, FORBIDDEN, INTERNAL_ERROR)'),
    'message': fields.String(description='Human readable error message')
})

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
