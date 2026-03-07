"""Ride Expiration Service - Handles automatic ride expiration and missed status."""

from datetime import datetime, timedelta
from app.extensions import db
from app.models.ride import Ride
from app.models.notification import Notification
import logging

logger = logging.getLogger(__name__)

# Grace periods
REMINDER_GRACE_MINUTES = 5  # Send reminder at departure + 5 minutes
EXPIRATION_GRACE_MINUTES = 10  # Mark as missed at departure + 10 minutes


def check_and_expire_rides():
    """
    Check scheduled rides and mark as missed if expired.
    Safe for lazy evaluation on ride fetch.
    Idempotent - can be called multiple times safely.
    
    Returns:
        tuple: (expired_count, reminded_count)
    """
    now = datetime.utcnow()
    expired_count = 0
    reminded_count = 0
    
    try:
        # Find scheduled rides that need processing
        scheduled_rides = Ride.query.filter(
            Ride.status.in_(['scheduled', 'ACTIVE', 'FULL']),
            Ride.is_deleted == False,
            Ride.departure_time < now  # Only past departure time
        ).all()
        
        logger.info(f'Expiration check: Found {len(scheduled_rides)} scheduled rides past departure time')
        logger.info(f'Current UTC time: {now}')
        
        for ride in scheduled_rides:
            logger.info(f'Checking ride {ride.id}: status={ride.status}, departure={ride.departure_time}')
            time_since_departure = now - ride.departure_time
            
            # Check for expiration (30 minutes past departure)
            if time_since_departure >= timedelta(minutes=EXPIRATION_GRACE_MINUTES):
                if _mark_ride_as_missed(ride):
                    expired_count += 1
                    logger.info(f'Ride {ride.id} marked as missed (expired)')
            
            # Check for reminder (10 minutes past departure)
            elif time_since_departure >= timedelta(minutes=REMINDER_GRACE_MINUTES):
                if _send_expiration_reminder(ride):
                    reminded_count += 1
                    logger.info(f'Expiration reminder sent for ride {ride.id}')
        
        if expired_count > 0 or reminded_count > 0:
            db.session.commit()
            logger.info(f'Expiration check: {expired_count} expired, {reminded_count} reminded')
        
        return expired_count, reminded_count
        
    except Exception as e:
        logger.error(f'Error in ride expiration check: {e}')
        db.session.rollback()
        return 0, 0


def _mark_ride_as_missed(ride):
    """
    Mark a ride as missed.
    Idempotent - safe to call multiple times.
    
    Args:
        ride: Ride object to mark as missed
        
    Returns:
        bool: True if status was changed, False if already missed
    """
    if ride.status == 'missed':
        return False  # Already missed
    
    # Validate transition is allowed
    if not ride.can_transition_to('missed'):
        logger.warning(f'Cannot transition ride {ride.id} from {ride.status} to missed')
        return False
    
    # Update status
    ride.status = 'missed'
    ride.updated_at = datetime.utcnow()
    
    # Notify driver
    _create_missed_notification(ride)
    
    return True


def _send_expiration_reminder(ride):
    """
    Send pre-expiration reminder to driver.
    Only sends once per ride.
    
    Args:
        ride: Ride object to send reminder for
        
    Returns:
        bool: True if reminder was sent, False if already sent
    """
    # Check if reminder already sent
    existing_reminder = Notification.query.filter_by(
        employee_id=ride.driver_id,
        ride_id=ride.id,
        type='ride_expiration_warning'
    ).first()
    
    if existing_reminder:
        return False  # Already sent
    
    # Create reminder notification
    notification = Notification(
        employee_id=ride.driver_id,
        ride_id=ride.id,
        type='ride_expiration_warning',
        message=f'Your ride from {ride.origin} to {ride.destination} has not started. '
                f'Please start it within the next 5 minutes or it will be marked as missed.',
        is_read=False,
        created_at=datetime.utcnow()
    )
    
    db.session.add(notification)
    return True


def _create_missed_notification(ride):
    """
    Create notification for missed ride.
    
    Args:
        ride: Ride object that was missed
    """
    notification = Notification(
        employee_id=ride.driver_id,
        ride_id=ride.id,
        type='ride_missed',
        message=f'Your ride from {ride.origin} to {ride.destination} was marked as missed '
                f'because it was not started within 10 minutes of departure time.',
        is_read=False,
        created_at=datetime.utcnow()
    )
    
    db.session.add(notification)
    
    # Also notify passengers with confirmed reservations
    from app.models.reservation import Reservation
    confirmed_reservations = Reservation.query.filter_by(
        ride_id=ride.id,
        status='CONFIRMED'
    ).all()
    
    for reservation in confirmed_reservations:
        passenger_notification = Notification(
            employee_id=reservation.employee_id,
            ride_id=ride.id,
            type='ride_missed',
            message=f'The ride from {ride.origin} to {ride.destination} was missed by the driver.',
            is_read=False,
            created_at=datetime.utcnow()
        )
        db.session.add(passenger_notification)


def check_single_ride_expiration(ride):
    """
    Check expiration for a single ride.
    Useful for lazy evaluation when fetching individual rides.
    
    Args:
        ride: Ride object to check
        
    Returns:
        bool: True if ride was updated, False otherwise
    """
    if ride.status not in ['scheduled', 'ACTIVE', 'FULL']:
        return False
    
    if ride.is_deleted:
        return False
    
    now = datetime.utcnow()
    
    # Only check rides past departure time
    if ride.departure_time >= now:
        return False
    
    time_since_departure = now - ride.departure_time
    
    # Check for expiration
    if time_since_departure >= timedelta(minutes=EXPIRATION_GRACE_MINUTES):
        if _mark_ride_as_missed(ride):
            db.session.commit()
            return True
    
    # Check for reminder
    elif time_since_departure >= timedelta(minutes=REMINDER_GRACE_MINUTES):
        if _send_expiration_reminder(ride):
            db.session.commit()
            return True
    
    return False
