"""Boarding Confirmation Service - Handles passenger boarding deadlines and auto-expiration."""

from datetime import datetime, timedelta
from app.extensions import db
from app.models.reservation import Reservation
from app.models.ride import Ride
from app.models.notification import Notification
import logging

logger = logging.getLogger(__name__)

# Boarding deadline grace period
BOARDING_GRACE_MINUTES = 5  # Passengers have 5 minutes to confirm boarding after arrival


def set_boarding_deadlines(ride_id):
    """
    Set boarding deadlines for all CONFIRMED reservations when ride status becomes 'arrived'.
    Called automatically when driver marks arrival.
    
    Args:
        ride_id: ID of the ride that has arrived
        
    Returns:
        int: Number of reservations with deadlines set
    """
    try:
        now = datetime.utcnow()
        deadline = now + timedelta(minutes=BOARDING_GRACE_MINUTES)
        
        # Get all CONFIRMED reservations for this ride
        reservations = Reservation.query.filter_by(
            ride_id=ride_id,
            status='CONFIRMED'
        ).all()
        
        count = 0
        for reservation in reservations:
            if not reservation.boarding_deadline:  # Only set if not already set
                reservation.boarding_deadline = deadline
                
                # Send notification to passenger
                _send_boarding_notification(reservation)
                count += 1
        
        if count > 0:
            db.session.commit()
            logger.info(f'Set boarding deadlines for {count} reservations on ride {ride_id}')
        
        return count
        
    except Exception as e:
        logger.error(f'Error setting boarding deadlines for ride {ride_id}: {e}')
        db.session.rollback()
        return 0


def confirm_boarding(reservation_id, employee_id):
    """
    Confirm passenger boarding.
    
    Args:
        reservation_id: ID of the reservation to confirm
        employee_id: ID of the employee confirming (must match reservation)
        
    Returns:
        tuple: (success: bool, message: str)
    """
    try:
        reservation = Reservation.query.get(reservation_id)
        
        if not reservation:
            return False, 'Reservation not found'
        
        # Verify employee owns this reservation
        if reservation.employee_id != employee_id:
            return False, 'Unauthorized - not your reservation'
        
        # Check reservation status
        if reservation.status != 'CONFIRMED':
            return False, f'Cannot confirm boarding - reservation status is {reservation.status}'
        
        # Check if already boarded
        if reservation.boarded:
            return True, 'Already confirmed boarding'
        
        # Check if deadline has passed
        if reservation.boarding_deadline:
            now = datetime.utcnow()
            if now > reservation.boarding_deadline:
                # Deadline passed - mark as MISSED
                reservation.status = 'MISSED'
                reservation.updated_at = now
                db.session.commit()
                return False, 'Boarding deadline has passed - marked as MISSED'
        
        # Confirm boarding
        reservation.boarded = True
        reservation.updated_at = datetime.utcnow()
        
        # Notify driver about passenger boarding confirmation
        _send_driver_boarding_confirmed_notification(reservation)
        
        db.session.commit()
        
        logger.info(f'Passenger {employee_id} confirmed boarding for reservation {reservation_id}')
        return True, 'Boarding confirmed successfully'
        
    except Exception as e:
        logger.error(f'Error confirming boarding for reservation {reservation_id}: {e}')
        db.session.rollback()
        return False, f'Error confirming boarding: {str(e)}'


def check_and_expire_boarding_deadlines():
    """
    Check all reservations with boarding deadlines and mark as MISSED if expired.
    Idempotent - safe to call multiple times.
    
    Returns:
        int: Number of reservations marked as MISSED
    """
    now = datetime.utcnow()
    expired_count = 0
    
    try:
        # Find CONFIRMED reservations with expired boarding deadlines
        expired_reservations = Reservation.query.filter(
            Reservation.status == 'CONFIRMED',
            Reservation.boarding_deadline.isnot(None),
            Reservation.boarding_deadline < now,
            Reservation.boarded == False
        ).all()
        
        logger.info(f'Boarding deadline check: Found {len(expired_reservations)} expired reservations')
        
        for reservation in expired_reservations:
            logger.info(f'Marking reservation {reservation.id} as MISSED (deadline expired)')
            
            # Mark as MISSED
            reservation.status = 'MISSED'
            reservation.updated_at = now
            
            # Notify passenger
            _send_missed_boarding_notification(reservation)
            
            # Notify driver
            _send_driver_passenger_missed_notification(reservation)
            
            expired_count += 1
        
        if expired_count > 0:
            db.session.commit()
            logger.info(f'Boarding deadline check: {expired_count} reservations marked as MISSED')
        
        return expired_count
        
    except Exception as e:
        logger.error(f'Error checking boarding deadlines: {e}')
        db.session.rollback()
        return 0


def _send_boarding_notification(reservation):
    """Send notification to passenger about boarding deadline."""
    ride = reservation.ride
    notification = Notification(
        employee_id=reservation.employee_id,
        ride_id=reservation.ride_id,
        type='boarding_required',
        message=f'Driver has arrived! Please confirm your boarding within 5 minutes for the ride '
                f'from {ride.origin} to {ride.destination}.',
        is_read=False,
        created_at=datetime.utcnow()
    )
    db.session.add(notification)


def _send_missed_boarding_notification(reservation):
    """Send notification to passenger that they missed boarding."""
    ride = reservation.ride
    notification = Notification(
        employee_id=reservation.employee_id,
        ride_id=reservation.ride_id,
        type='boarding_missed',
        message=f'You missed the boarding deadline for the ride from {ride.origin} to {ride.destination}. '
                f'Your reservation has been cancelled.',
        is_read=False,
        created_at=datetime.utcnow()
    )
    db.session.add(notification)


def _send_driver_passenger_missed_notification(reservation):
    """Send notification to driver that a passenger missed boarding."""
    ride = reservation.ride
    notification = Notification(
        employee_id=ride.driver_id,
        ride_id=reservation.ride_id,
        type='passenger_missed_boarding',
        message=f'Passenger missed boarding deadline. {reservation.seats_reserved} seat(s) released.',
        is_read=False,
        created_at=datetime.utcnow()
    )
    db.session.add(notification)


def _send_driver_boarding_confirmed_notification(reservation):
    """Send notification to driver that a passenger confirmed boarding."""
    from app.models.employee import Employee
    ride = reservation.ride
    passenger = Employee.query.get(reservation.employee_id)
    passenger_name = passenger.name if passenger else 'Passenger'
    
    notification = Notification(
        employee_id=ride.driver_id,
        ride_id=reservation.ride_id,
        type='passenger_boarded',
        message=f'{passenger_name} has confirmed boarding ({reservation.seats_reserved} seat(s)).',
        is_read=False,
        created_at=datetime.utcnow()
    )
    db.session.add(notification)


def get_active_reservations(ride_id):
    """
    Get active reservations for a ride (excludes MISSED passengers).
    Used when driver begins the ride.
    
    Args:
        ride_id: ID of the ride
        
    Returns:
        list: List of active Reservation objects
    """
    return Reservation.query.filter(
        Reservation.ride_id == ride_id,
        Reservation.status == 'CONFIRMED',
        Reservation.status != 'MISSED'
    ).all()
