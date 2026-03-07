"""Ride Auto-Termination Service - Prevents rides from staying active indefinitely.

Handles automatic termination of rides that exceed reasonable durations in:
- driver_en_route: Auto-cancel if driver doesn't arrive within ETA + grace period
- arrived: Auto-cancel if boarding window expires
- in_progress: Auto-complete if journey exceeds ETA + grace period

Uses OSRM for route duration estimation and lazy evaluation pattern.
"""

from datetime import datetime, timedelta
from app.extensions import db
from app.models.ride import Ride
from app.models.notification import Notification
import requests
import logging

logger = logging.getLogger(__name__)

# Configurable grace periods
BOARDING_WINDOW_MINUTES = 15  # Time driver waits at pickup before auto-cancel
DRIVER_EN_ROUTE_GRACE_MINUTES = 30  # Extra time for driver to reach pickup
IN_PROGRESS_GRACE_MINUTES = 120  # Extra time for journey completion (2 hours)

# OSRM API endpoint
OSRM_BASE_URL = 'https://router.project-osrm.org/route/v1/driving'


def calculate_route_duration(origin_lat, origin_lng, dest_lat, dest_lng):
    """
    Calculate estimated travel time using OSRM API.
    
    Args:
        origin_lat: Origin latitude
        origin_lng: Origin longitude
        dest_lat: Destination latitude
        dest_lng: Destination longitude
        
    Returns:
        int: Duration in seconds, or None if calculation fails
    """
    try:
        url = f"{OSRM_BASE_URL}/{origin_lng},{origin_lat};{dest_lng},{dest_lat}"
        response = requests.get(url, timeout=10)
        
        if response.status_code != 200:
            logger.warning(f'OSRM API returned status {response.status_code}')
            return None
        
        data = response.json()
        if data.get('code') != 'Ok' or not data.get('routes'):
            logger.warning(f'OSRM API returned invalid data: {data.get("code")}')
            return None
        
        duration = data['routes'][0]['duration']  # seconds
        logger.info(f'OSRM route duration: {duration}s ({duration/60:.1f} min)')
        return int(duration)
    except Exception as e:
        logger.error(f"OSRM route calculation failed: {e}")
        return None


def check_and_terminate_rides():
    """
    Check all active rides and auto-terminate if they exceed reasonable durations.
    Called lazily on ride fetch operations.
    Idempotent - safe to call multiple times.
    
    Returns:
        int: Total number of rides terminated
    """
    now = datetime.utcnow()
    terminated_count = 0
    
    try:
        # Check driver_en_route rides
        terminated_count += _check_driver_en_route_rides(now)
        
        # Check arrived rides
        terminated_count += _check_arrived_rides(now)
        
        # Check in_progress rides
        terminated_count += _check_in_progress_rides(now)
        
        if terminated_count > 0:
            db.session.commit()
            logger.info(f'Auto-termination: {terminated_count} rides terminated')
        
        return terminated_count
        
    except Exception as e:
        logger.error(f'Error in ride auto-termination check: {e}')
        db.session.rollback()
        return 0


def _check_driver_en_route_rides(now):
    """
    Auto-cancel rides where driver never arrived at pickup.
    
    Args:
        now: Current UTC datetime
        
    Returns:
        int: Number of rides cancelled
    """
    rides = Ride.query.filter_by(status='driver_en_route', is_deleted=False).all()
    count = 0
    
    for ride in rides:
        # Calculate expected arrival time at pickup
        # Use origin coordinates as driver's starting point
        if not all([ride.origin_lat, ride.origin_lng]):
            logger.warning(f'Ride {ride.id} missing origin coordinates, skipping')
            continue
        
        # Calculate route duration to pickup (origin)
        route_duration = calculate_route_duration(
            ride.origin_lat, ride.origin_lng,
            ride.origin_lat, ride.origin_lng  # Same point, so duration will be 0
        )
        
        # Use default if calculation fails
        if route_duration is None:
            route_duration = 1800  # Default 30 minutes
        
        grace_period = timedelta(minutes=DRIVER_EN_ROUTE_GRACE_MINUTES)
        max_time = ride.departure_time + timedelta(seconds=route_duration) + grace_period
        
        if now > max_time:
            ride.status = 'cancelled'
            ride.cancelled_at = now
            ride.updated_at = now
            _notify_ride_auto_cancelled(ride, 'driver_no_show')
            count += 1
            logger.info(
                f'Auto-cancelled ride {ride.id} (driver_en_route): '
                f'exceeded {DRIVER_EN_ROUTE_GRACE_MINUTES}min grace period'
            )
    
    return count


def _check_arrived_rides(now):
    """
    Auto-cancel rides where boarding window expired.
    
    Args:
        now: Current UTC datetime
        
    Returns:
        int: Number of rides cancelled
    """
    rides = Ride.query.filter_by(status='arrived', is_deleted=False).all()
    count = 0
    
    for ride in rides:
        boarding_window = timedelta(minutes=BOARDING_WINDOW_MINUTES)
        max_time = ride.updated_at + boarding_window
        
        if now > max_time:
            ride.status = 'cancelled'
            ride.cancelled_at = now
            ride.updated_at = now
            _notify_ride_auto_cancelled(ride, 'boarding_expired')
            count += 1
            logger.info(
                f'Auto-cancelled ride {ride.id} (arrived): '
                f'exceeded {BOARDING_WINDOW_MINUTES}min boarding window'
            )
    
    return count


def _check_in_progress_rides(now):
    """
    Auto-complete rides that took too long.
    
    Args:
        now: Current UTC datetime
        
    Returns:
        int: Number of rides completed
    """
    rides = Ride.query.filter_by(status='in_progress', is_deleted=False).all()
    count = 0
    
    for ride in rides:
        # Calculate expected journey time
        if not all([ride.origin_lat, ride.origin_lng, ride.destination_lat, ride.destination_lng]):
            logger.warning(f'Ride {ride.id} missing coordinates, skipping')
            continue
        
        route_duration = calculate_route_duration(
            ride.origin_lat, ride.origin_lng,
            ride.destination_lat, ride.destination_lng
        )
        
        # Use default if calculation fails
        if route_duration is None:
            route_duration = 3600  # Default 1 hour
        
        grace_period = timedelta(minutes=IN_PROGRESS_GRACE_MINUTES)
        max_time = ride.updated_at + timedelta(seconds=route_duration) + grace_period
        
        if now > max_time:
            ride.status = 'completed'
            ride.updated_at = now
            _notify_ride_auto_completed(ride)
            count += 1
            logger.info(
                f'Auto-completed ride {ride.id} (in_progress): '
                f'exceeded {IN_PROGRESS_GRACE_MINUTES}min grace period'
            )
    
    return count


def _notify_ride_auto_cancelled(ride, reason):
    """
    Send notifications when ride is auto-cancelled.
    
    Args:
        ride: Ride object that was cancelled
        reason: Cancellation reason ('driver_no_show' or 'boarding_expired')
    """
    try:
        if reason == 'driver_no_show':
            message = f'Ride from {ride.origin} to {ride.destination} was automatically cancelled - driver did not arrive at pickup location.'
        elif reason == 'boarding_expired':
            message = f'Ride from {ride.origin} to {ride.destination} was automatically cancelled - boarding window expired.'
        else:
            message = f'Ride from {ride.origin} to {ride.destination} was automatically cancelled.'
        
        # Notify driver
        notification = Notification(
            employee_id=ride.driver_id,
            ride_id=ride.id,
            message=message,
            type='ride_auto_cancelled',
            is_read=False
        )
        db.session.add(notification)
        
        # Notify all passengers with confirmed reservations
        for reservation in ride.reservations:
            if reservation.status == 'CONFIRMED':
                passenger_notification = Notification(
                    employee_id=reservation.employee_id,
                    ride_id=ride.id,
                    message=message,
                    type='ride_auto_cancelled',
                    is_read=False
                )
                db.session.add(passenger_notification)
        
        logger.info(f'Sent auto-cancellation notifications for ride {ride.id}')
        
    except Exception as e:
        logger.error(f'Error sending auto-cancellation notifications for ride {ride.id}: {e}')


def _notify_ride_auto_completed(ride):
    """
    Send notifications when ride is auto-completed.
    
    Args:
        ride: Ride object that was completed
    """
    try:
        message = f'Ride from {ride.origin} to {ride.destination} was automatically completed - exceeded expected journey duration.'
        
        # Notify driver
        notification = Notification(
            employee_id=ride.driver_id,
            ride_id=ride.id,
            message=message,
            type='ride_auto_completed',
            is_read=False
        )
        db.session.add(notification)
        
        # Notify all passengers with confirmed reservations
        for reservation in ride.reservations:
            if reservation.status == 'CONFIRMED':
                passenger_notification = Notification(
                    employee_id=reservation.employee_id,
                    ride_id=ride.id,
                    message=message,
                    type='ride_auto_completed',
                    is_read=False
                )
                db.session.add(passenger_notification)
        
        logger.info(f'Sent auto-completion notifications for ride {ride.id}')
        
    except Exception as e:
        logger.error(f'Error sending auto-completion notifications for ride {ride.id}: {e}')
