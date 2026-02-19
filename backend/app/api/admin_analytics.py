"""Admin Analytics API - Real-time dashboard metrics and trends."""

from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity
from app.models.employee import Employee
from app.services.system_metrics_service import get_dashboard_metrics
from app.services.admin_analytics_service import AdminAnalyticsService

api = Namespace('admin/analytics', description='Admin analytics and statistics endpoints')

# Response models
dashboard_summary_model = api.model('DashboardSummary', {
    'users_total': fields.Integer(description='Total number of users'),
    'users_today': fields.Integer(description='Users created today'),
    'active_rides': fields.Integer(description='Active rides (ACTIVE or FULL status)'),
    'rides_total': fields.Integer(description='Total number of rides'),
    'reservations_total': fields.Integer(description='Total number of reservations'),
    'system_status': fields.String(description='System operational status')
})

trend_item_model = api.model('TrendItem', {
    'date': fields.String(description='Date in YYYY-MM-DD format'),
    'count': fields.Integer(description='Count for that date')
})

trends_model = api.model('Trends', {
    'rides_per_day': fields.List(fields.Nested(trend_item_model)),
    'reservations_per_day': fields.List(fields.Nested(trend_item_model))
})

top_route_model = api.model('TopRoute', {
    'origin': fields.String(description='Origin location'),
    'destination': fields.String(description='Destination location'),
    'rides': fields.Integer(description='Number of rides for this route'),
    'reservations': fields.Integer(description='Number of reservations for this route')
})

top_routes_model = api.model('TopRoutes', {
    'routes': fields.List(fields.Nested(top_route_model))
})

status_distribution_model = api.model('RideStatusDistribution', {
    'active': fields.Integer(description='Active rides count (ACTIVE + FULL)'),
    'completed': fields.Integer(description='Completed rides count'),
    'cancelled': fields.Integer(description='Cancelled rides count')
})

recent_activity_item_model = api.model('RecentActivityItem', {
    'user': fields.String(description='User full name'),
    'route': fields.String(description='Route (Origin → Destination)'),
    'time': fields.String(description='ISO timestamp'),
    'status': fields.String(description='Reservation status')
})

recent_activity_model = api.model('RecentActivity', {
    'items': fields.List(fields.Nested(recent_activity_item_model))
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


@api.route('/dashboard')
class DashboardSummary(Resource):
    @jwt_required()
    @api.doc(
        'get_dashboard_summary',
        security='Bearer',
        description='Get dashboard summary metrics',
        responses={
            200: ('Dashboard summary', dashboard_summary_model),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Admin access required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(dashboard_summary_model)
    def get(self):
        """Get dashboard summary metrics."""
        result = require_admin()
        if isinstance(result, tuple):
            return result

        return get_dashboard_metrics()


@api.route('/trends')
class SystemTrends(Resource):
    @jwt_required()
    @api.doc(
        'get_trends',
        security='Bearer',
        description='Get system trends for the last N days',
        params={'days': {'description': 'Number of days (1-365, default 7)', 'type': 'integer'}},
        responses={
            200: ('System trends', trends_model),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Admin access required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(trends_model)
    def get(self):
        """Get system trends for the last N days."""
        result = require_admin()
        if isinstance(result, tuple):
            return result

        # Get days parameter with validation
        from flask import request
        try:
            days = int(request.args.get('days', 7))
        except (ValueError, TypeError):
            days = 7

        return AdminAnalyticsService.get_trends(days)


@api.route('/top-routes')
class TopRoutes(Resource):
    @jwt_required()
    @api.doc(
        'get_top_routes',
        security='Bearer',
        description='Get top 5 routes by reservation count',
        responses={
            200: ('Top routes', top_routes_model),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Admin access required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(top_routes_model)
    def get(self):
        """Get top 5 routes by reservation count."""
        result = require_admin()
        if isinstance(result, tuple):
            return result

        return AdminAnalyticsService.get_top_routes()


@api.route('/status-distribution')
class RideStatusDistribution(Resource):
    @jwt_required()
    @api.doc(
        'get_status_distribution',
        security='Bearer',
        description='Get ride status distribution for donut chart',
        responses={
            200: ('Ride status distribution', status_distribution_model),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Admin access required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(status_distribution_model)
    def get(self):
        """Get ride status distribution."""
        result = require_admin()
        if isinstance(result, tuple):
            return result

        return AdminAnalyticsService.get_ride_status_distribution()


@api.route('/recent-activity')
class RecentActivity(Resource):
    @jwt_required()
    @api.doc(
        'get_recent_activity',
        security='Bearer',
        description='Get recent reservation activity for activity table',
        params={'limit': {'description': 'Number of items (1-100, default 10)', 'type': 'integer'}},
        responses={
            200: ('Recent activity', recent_activity_model),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Admin access required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(recent_activity_model)
    def get(self):
        """Get recent reservation activity."""
        result = require_admin()
        if isinstance(result, tuple):
            return result

        from flask import request
        try:
            limit = int(request.args.get('limit', 10))
        except (ValueError, TypeError):
            limit = 10

        return AdminAnalyticsService.get_recent_activity(limit=limit)
