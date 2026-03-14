from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity

from app.extensions import db
from app.models import Employee, Ride, Reservation
from app.models.system_event import SystemEvent
from app.services.system_metrics_service import (
    get_total_users,
    get_active_rides as get_service_active_rides,
    get_total_rides,
    get_total_reservations,
)
from app.services.system_health_service import get_system_health

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


@api.route('/users/<int:id>')
class AdminUserDetails(Resource):
    @jwt_required()
    @api.doc('get_user_details', security='Bearer', description='Get detailed employee information (Admin only)',
        responses={
            200: ('Employee details with car info and usage stats'),
            403: ('Forbidden - Admin access required', error_response),
            404: ('User not found', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self, id):
        """Get detailed employee profile including car info and usage statistics"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        user = Employee.query.get(id)
        if not user:
            return {'error': 'NOT_FOUND', 'message': 'User not found'}, 404
        
        # Build car object only if car info exists
        car = None
        if user.car_model or user.car_plate or user.car_color:
            car = {
                'model': user.car_model,
                'color': user.car_color,
                'license_plate': user.car_plate
            }
        
        # Calculate usage statistics
        rides_offered = user.offered_rides.count()
        reservations_made = user.reservations.count()
        
        # Completed trips (rides where user was driver and status is completed)
        completed_trips = user.offered_rides.filter(
            Ride.status == 'completed'
        ).count()
        
        # Cancelled trips (rides where user was driver and status is CANCELLED)
        cancelled_trips = user.offered_rides.filter(
            Ride.status == 'CANCELLED'
        ).count()
        
        # Build response
        response = {
            'id': user.id,
            'name': user.name,
            'email': user.email,
            'status': user.status,
            'department': user.department,
            'phone_number': user.phone_number,
            'created_at': user.created_at.isoformat() if user.created_at else None,
            'last_login': user.last_seen_at.isoformat() if user.last_seen_at else None,
            'car': car,
            'rides_offered': rides_offered,
            'reservations_made': reservations_made,
            'completed_trips': completed_trips,
            'cancelled_trips': cancelled_trips
        }
        
        return response


@api.route('/users/<int:id>/activity')
class AdminUserActivity(Resource):
    @jwt_required()
    @api.doc('get_user_activity', security='Bearer', description='Get employee activity timeline (Admin only)',
        params={
            'limit': {'description': 'Number of events to return (default 20, max 100)', 'type': 'integer', 'default': 20},
            'offset': {'description': 'Offset for pagination (default 0)', 'type': 'integer', 'default': 0}
        },
        responses={
            200: ('List of employee activity events'),
            403: ('Forbidden - Admin access required', error_response),
            404: ('User not found', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self, id):
        """Get activity timeline for a specific employee with pagination"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        # Verify user exists
        user = Employee.query.get(id)
        if not user:
            return {'error': 'NOT_FOUND', 'message': 'User not found'}, 404
        
        # Get pagination parameters
        from flask import request
        try:
            limit = int(request.args.get('limit', 20))
            limit = max(1, min(100, limit))  # Clamp between 1 and 100
        except (ValueError, TypeError):
            limit = 20
        
        try:
            offset = int(request.args.get('offset', 0))
            offset = max(0, offset)  # Ensure non-negative
        except (ValueError, TypeError):
            offset = 0
        
        # Fetch events for this employee
        events = SystemEvent.query.filter(
            SystemEvent.employee_id == id
        ).order_by(SystemEvent.created_at.desc()).offset(offset).limit(limit).all()
        
        # Format response
        return [
            {
                'type': event.event_type,
                'description': event.message,
                'timestamp': event.created_at.isoformat() if event.created_at else None,
                'ride_id': event.ride_id,
                'reservation_id': event.reservation_id,
                'severity': event.severity,
                'entity_type': event.entity_type
            }
            for event in events
        ]


@api.route('/events')
class AdminEvents(Resource):
    @jwt_required()
    @api.doc('get_events', security='Bearer', description='Get recent system events (Admin only)',
        params={
            'limit': {'description': 'Number of events to return (default 20, max 100)', 'type': 'integer', 'default': 20},
            'offset': {'description': 'Offset for pagination (default 0)', 'type': 'integer', 'default': 0}
        },
        responses={
            200: ('List of recent system events'),
            403: ('Forbidden - Admin access required', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self):
        """Get recent system events for admin dashboard with pagination"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        # Get limit parameter with validation
        from flask import request
        try:
            limit = int(request.args.get('limit', 20))
            limit = max(1, min(100, limit))  # Clamp between 1 and 100
        except (ValueError, TypeError):
            limit = 20
        
        # Get offset parameter with validation
        try:
            offset = int(request.args.get('offset', 0))
            offset = max(0, offset)  # Ensure non-negative
        except (ValueError, TypeError):
            offset = 0
        
        # Fetch events with pagination
        events = SystemEvent.query.order_by(SystemEvent.created_at.desc()).offset(offset).limit(limit).all()
        
        # Format response
        return [
            {
                'type': event.event_type,  # Keep uppercase: RIDE_STARTED
                'description': event.message,
                'timestamp': event.created_at.isoformat() if event.created_at else None,
                'entity_type': event.entity_type,
                'user': event.employee.name if event.employee else None,
                'user_id': event.employee_id,
                'ride_id': event.ride_id,
                'reservation_id': event.reservation_id,
                'severity': event.severity,
                'metadata': event.event_metadata
            }
            for event in events
        ]


# System Health endpoint
system_health_response = api.model('SystemHealthResponse', {
    'api': fields.String(description='API server status'),
    'database': fields.String(description='Database health status'),
    'websocket': fields.String(description='WebSocket service status'),
    'osrm': fields.String(description='OSRM routing service status'),
    'gps_stream': fields.String(description='GPS stream activity status'),
    'checked_at': fields.String(description='ISO timestamp when health was checked')
})


@api.route('/system-health')
class AdminSystemHealth(Resource):
    @jwt_required()
    @api.doc('get_system_health', security='Bearer', description='Get system health status (Admin only)',
        responses={
            200: ('System health status', system_health_response),
            403: ('Forbidden - Admin access required', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self):
        """Get real-time system health status of all core services"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        # Get health status from service
        health_status = get_system_health()
        return health_status


# Dashboard Metrics endpoint
dashboard_metrics_response = api.model('DashboardMetricsResponse', {
    'active_rides': fields.Integer(description='Number of active/in_progress rides'),
    'online_users': fields.Integer(description='Number of online users (last seen within 5 min)'),
    'pending_requests': fields.Integer(description='Number of pending reservation requests'),
    'active_sessions': fields.Integer(description='Number of active user sessions (estimated)')
})


@api.route('/dashboard-metrics')
class AdminDashboardMetrics(Resource):
    @jwt_required()
    @api.doc('get_dashboard_metrics', security='Bearer', description='Get real-time dashboard metrics (Admin only)',
        responses={
            200: ('Dashboard metrics', dashboard_metrics_response),
            403: ('Forbidden - Admin access required', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self):
        """Get real-time dashboard metrics for admin overview"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        from datetime import datetime, timedelta
        
        # Active rides (in_progress or active status)
        active_rides = Ride.query.filter(
            Ride.status.in_(['in_progress', 'active'])
        ).count()
        
        # Online users (last seen within last 5 minutes)
        # Note: This requires last_seen_at field on Employee model
        try:
            recent_threshold = datetime.utcnow() - timedelta(minutes=5)
            online_users = Employee.query.filter(
                Employee.last_seen_at >= recent_threshold
            ).count()
        except Exception:
            # Fallback: count users who have been active recently via rides/reservations
            online_users = Employee.query.filter(
                Employee.role == 'employee'
            ).count()
        
        # Pending reservation requests
        pending_requests = Reservation.query.filter(
            Reservation.status == 'PENDING'
        ).count()
        
        # Active sessions (estimated from online users + drivers with active rides)
        active_drivers = Ride.query.filter(
            Ride.status.in_(['in_progress', 'active'])
        ).distinct(Ride.driver_id).count()
        active_sessions = online_users + active_drivers
        
        return {
            'active_rides': active_rides,
            'online_users': online_users,
            'pending_requests': pending_requests,
            'active_sessions': active_sessions
        }


# Analytics Endpoints
@api.route('/analytics/ride-status')
class AdminAnalyticsRideStatus(Resource):
    @jwt_required()
    @api.doc('get_ride_status_analytics', security='Bearer', description='Get ride status distribution (Admin only)',
        responses={
            200: ('Ride status distribution'),
            403: ('Forbidden - Admin access required', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self):
        """Get ride status distribution for analytics"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        from sqlalchemy import func
        
        # Query rides grouped by status
        status_counts = db.session.query(
            Ride.status,
            func.count(Ride.id).label('count')
        ).group_by(Ride.status).all()
        
        # Build response dictionary
        distribution = {}
        for status, count in status_counts:
            if status:
                distribution[status] = count
        
        return distribution


@api.route('/analytics/rides-over-time')
class AdminAnalyticsRidesOverTime(Resource):
    @jwt_required()
    @api.doc('get_rides_over_time', security='Bearer', description='Get ride activity over time (Admin only)',
        responses={
            200: ('Ride activity timeline'),
            403: ('Forbidden - Admin access required', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self):
        """Get ride activity grouped by date"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        from sqlalchemy import func, cast, Date
        
        # Query rides grouped by date
        rides_by_date = db.session.query(
            cast(Ride.created_at, Date).label('date'),
            func.count(Ride.id).label('rides')
        ).group_by(cast(Ride.created_at, Date)).order_by(cast(Ride.created_at, Date)).all()
        
        # Format response
        return [
            {
                'date': date.isoformat() if date else None,
                'rides': rides
            }
            for date, rides in rides_by_date
        ]


@api.route('/analytics/top-routes')
class AdminAnalyticsTopRoutes(Resource):
    @jwt_required()
    @api.doc('get_top_routes', security='Bearer', description='Get most frequent routes (Admin only)',
        params={
            'country': {'description': 'Filter by country (tunisia or france)', 'type': 'string', 'required': False}
        },
        responses={
            200: ('Top routes list'),
            403: ('Forbidden - Admin access required', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self):
        """Get top 3 most frequent routes, optionally filtered by country"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        from sqlalchemy import func, or_
        from flask import request
        
        country = request.args.get('country', '').lower()
        
        # Build query
        query = db.session.query(
            Ride.origin,
            Ride.destination,
            func.count(Ride.id).label('rides')
        )
        
        # Apply country filter if specified
        if country == 'tunisia':
            query = query.filter(
                or_(
                    Ride.origin.ilike('%tunisia%'),
                    Ride.origin.ilike('%tunis%'),
                    Ride.destination.ilike('%tunisia%'),
                    Ride.destination.ilike('%tunis%')
                )
            )
        elif country == 'france':
            query = query.filter(
                or_(
                    Ride.origin.ilike('%france%'),
                    Ride.destination.ilike('%france%')
                )
            )
        
        # Execute query
        top_routes = query.group_by(
            Ride.origin,
            Ride.destination
        ).order_by(
            func.count(Ride.id).desc()
        ).limit(3).all()
        
        # Format response
        return [
            {
                'origin': origin or 'Unknown',
                'destination': destination or 'Unknown',
                'rides': rides
            }
            for origin, destination, rides in top_routes
        ]


@api.route('/analytics/user-growth')
class AdminAnalyticsUserGrowth(Resource):
    @jwt_required()
    @api.doc('get_user_growth', security='Bearer', description='Get user registration growth over time (Admin only)',
        responses={
            200: ('User growth timeline'),
            403: ('Forbidden - Admin access required', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self):
        """Get employee registration data grouped by date"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        from sqlalchemy import func, cast, Date
        
        # Query employees grouped by registration date
        users_by_date = db.session.query(
            cast(Employee.created_at, Date).label('date'),
            func.count(Employee.id).label('users')
        ).group_by(cast(Employee.created_at, Date)).order_by(cast(Employee.created_at, Date)).all()
        
        # Format response
        return [
            {
                'date': date.isoformat() if date else None,
                'users': users
            }
            for date, users in users_by_date
        ]


@api.route('/analytics/reservation-funnel')
class AdminAnalyticsReservationFunnel(Resource):
    @jwt_required()
    @api.doc('get_reservation_funnel', security='Bearer', description='Get reservation conversion funnel (Admin only)',
        responses={
            200: ('Reservation funnel metrics'),
            403: ('Forbidden - Admin access required', error_response),
            401: ('Unauthorized - JWT required', error_response)
        }
    )
    def get(self):
        """Get reservation funnel from system events"""
        result = require_admin()
        if isinstance(result, tuple):  # Error response
            return result
        
        # Count events by type
        requested = SystemEvent.query.filter(
            SystemEvent.event_type == 'RESERVATION_REQUESTED'
        ).count()
        
        confirmed = SystemEvent.query.filter(
            SystemEvent.event_type == 'RESERVATION_CONFIRMED'
        ).count()
        
        boarded = SystemEvent.query.filter(
            SystemEvent.event_type == 'PASSENGER_BOARDED'
        ).count()
        
        return {
            'requested': requested,
            'confirmed': confirmed,
            'boarded': boarded
        }
