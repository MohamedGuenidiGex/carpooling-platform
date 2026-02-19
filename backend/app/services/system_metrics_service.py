"""System Metrics Service - Shared metric calculations for consistency.

This module provides centralized metric calculations used by both
the admin dashboard and analytics endpoints to ensure consistent data.
"""

from datetime import datetime, timedelta
from sqlalchemy import func, cast, Date
from app import db
from app.models.employee import Employee
from app.models.ride import Ride
from app.models.reservation import Reservation


def get_total_users():
    """Get total count of all users/employees."""
    return db.session.query(func.count(Employee.id)).scalar() or 0


def get_users_today():
    """Get count of users created today."""
    today = datetime.utcnow().date()
    today_start = datetime.combine(today, datetime.min.time())
    today_end = datetime.combine(today, datetime.max.time())

    return (
        db.session.query(func.count(Employee.id))
        .filter(
            Employee.created_at >= today_start,
            Employee.created_at <= today_end
        )
        .scalar() or 0
    )


def get_active_rides():
    """Get count of rides with status ACTIVE or FULL."""
    return (
        db.session.query(func.count(Ride.id))
        .filter(Ride.status.in_(['ACTIVE', 'FULL']))
        .scalar() or 0
    )


def get_total_rides():
    """Get total count of all rides."""
    return db.session.query(func.count(Ride.id)).scalar() or 0


def get_total_reservations():
    """Get total count of non-cancelled reservations."""
    return (
        db.session.query(func.count(Reservation.id))
        .filter(Reservation.status != 'CANCELLED')
        .scalar() or 0
    )


def get_system_status():
    """Get system operational status."""
    return 'operational'


def get_dashboard_metrics():
    """Get all dashboard metrics in a single call.
    
    Returns:
        dict: Contains all dashboard metrics
    """
    return {
        'users_total': get_total_users(),
        'users_today': get_users_today(),
        'active_rides': get_active_rides(),
        'rides_total': get_total_rides(),
        'reservations_total': get_total_reservations(),
        'system_status': get_system_status()
    }
