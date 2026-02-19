"""Admin Monitoring Service - Real-time system monitoring metrics."""

from datetime import datetime, timedelta
from sqlalchemy import func
from app import db
from app.models import Employee, Ride, Reservation, SystemEvent


def update_last_seen(employee_id):
    """Update the last_seen_at timestamp for an employee.
    
    Call this whenever an employee makes an API request to track activity.
    """
    try:
        employee = Employee.query.get(employee_id)
        if employee:
            employee.last_seen_at = datetime.utcnow()
            db.session.commit()
    except Exception as e:
        db.session.rollback()
        import logging
        logging.error(f'Error updating last_seen for employee {employee_id}: {e}')


def get_online_users(minutes=10):
    """Get count of users active in the last N minutes.
    
    Args:
        minutes: Time window for "online" (default 10 minutes)
        
    Returns:
        int: Count of online users
    """
    try:
        cutoff = datetime.utcnow() - timedelta(minutes=minutes)
        count = (
            db.session.query(func.count(Employee.id))
            .filter(
                Employee.last_seen_at.isnot(None),
                Employee.last_seen_at >= cutoff
            )
            .scalar() or 0
        )
        return count
    except Exception as e:
        import logging
        logging.error(f'Error getting online users: {e}')
        return 0


def get_active_rides_now():
    """Get count of currently active rides (ACTIVE or FULL status).
    
    Returns:
        int: Count of active rides
    """
    try:
        count = (
            db.session.query(func.count(Ride.id))
            .filter(Ride.status.in_(['ACTIVE', 'FULL']))
            .scalar() or 0
        )
        return count
    except Exception as e:
        import logging
        logging.error(f'Error getting active rides: {e}')
        return 0


def get_pending_requests():
    """Get count of pending reservation requests.
    
    Returns:
        int: Count of PENDING reservations
    """
    try:
        count = (
            db.session.query(func.count(Reservation.id))
            .filter(Reservation.status == 'PENDING')
            .scalar() or 0
        )
        return count
    except Exception as e:
        import logging
        logging.error(f'Error getting pending requests: {e}')
        return 0


def get_active_sessions():
    """Get count of active user sessions.
    
    For now, this uses the same logic as online users (last_seen within 30 min).
    In a more advanced implementation, this could track actual JWT sessions.
    
    Returns:
        int: Count of active sessions
    """
    try:
        # Use a longer window for "sessions" vs "online now"
        cutoff = datetime.utcnow() - timedelta(minutes=30)
        count = (
            db.session.query(func.count(Employee.id))
            .filter(
                Employee.last_seen_at.isnot(None),
                Employee.last_seen_at >= cutoff
            )
            .scalar() or 0
        )
        return count
    except Exception as e:
        import logging
        logging.error(f'Error getting active sessions: {e}')
        return 0


def get_system_health():
    """Get overall system health status.
    
    Returns:
        dict: Contains status ('operational' or 'degraded'), message, and last_updated
    """
    try:
        # Check for any critical events in the last hour
        one_hour_ago = datetime.utcnow() - timedelta(hours=1)
        critical_count = (
            db.session.query(func.count(SystemEvent.id))
            .filter(
                SystemEvent.severity == 'critical',
                SystemEvent.created_at >= one_hour_ago
            )
            .scalar() or 0
        )
        
        if critical_count > 0:
            return {
                'status': 'degraded',
                'message': f'{critical_count} critical event(s) detected',
                'last_updated': datetime.utcnow().isoformat()
            }
        
        return {
            'status': 'operational',
            'message': 'All systems operational',
            'last_updated': datetime.utcnow().isoformat()
        }
    except Exception as e:
        import logging
        logging.error(f'Error checking system health: {e}')
        return {
            'status': 'unknown',
            'message': 'Unable to determine system status',
            'last_updated': datetime.utcnow().isoformat()
        }


def get_recent_events(limit=5):
    """Get recent system events for the monitoring dashboard.
    
    Args:
        limit: Maximum number of events to return
        
    Returns:
        list: Recent system events as dictionaries
    """
    try:
        events = (
            SystemEvent.query
            .order_by(SystemEvent.created_at.desc())
            .limit(limit)
            .all()
        )
        return [event.to_dict() for event in events]
    except Exception as e:
        import logging
        logging.error(f'Error getting recent events: {e}')
        return []


def get_monitoring_overview():
    """Get complete monitoring overview for the admin dashboard.
    
    Returns:
        dict: Complete monitoring data including all metrics and events
    """
    return {
        'system_health': get_system_health(),
        'live_metrics': {
            'active_rides_now': get_active_rides_now(),
            'online_users': get_online_users(minutes=10),
            'pending_requests': get_pending_requests(),
            'active_sessions': get_active_sessions()
        },
        'recent_events': get_recent_events(limit=5)
    }
