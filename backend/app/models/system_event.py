from app.extensions import db
from datetime import datetime
from sqlalchemy.dialects.postgresql import JSON

class SystemEvent(db.Model):
    __tablename__ = 'system_events'

    id = db.Column(db.Integer, primary_key=True)
    event_type = db.Column(db.String(50), nullable=False)
    message = db.Column(db.Text, nullable=False)
    severity = db.Column(db.String(20), nullable=False, default='info')  # info, warning, critical
    entity_type = db.Column(db.String(20), nullable=True)  # ride, reservation, user, system
    employee_id = db.Column(db.Integer, db.ForeignKey('employees.id'), nullable=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('rides.id'), nullable=True)
    reservation_id = db.Column(db.Integer, db.ForeignKey('reservations.id'), nullable=True)
    event_metadata = db.Column(JSON, nullable=True)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

    # Relationships
    employee = db.relationship('Employee', lazy='joined')
    ride = db.relationship('Ride', lazy='joined')
    reservation = db.relationship('Reservation', lazy='joined')

    def to_dict(self):
        return {
            'id': self.id,
            'event_type': self.event_type,
            'message': self.message,
            'severity': self.severity,
            'entity_type': self.entity_type,
            'employee': self.employee.name if self.employee else None,
            'employee_id': self.employee_id,
            'ride_id': self.ride_id,
            'reservation_id': self.reservation_id,
            'metadata': self.event_metadata,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

    def __repr__(self):
        return f'<SystemEvent {self.event_type} {self.severity}>'


def log_system_event(event_type, description=None, message=None, severity='info', entity_type=None, user_id=None, employee_id=None, ride_id=None, reservation_id=None, metadata=None):
    """Create a system event log entry with safe error handling.
    
    Args:
        event_type: Type of event (e.g., RIDE_CREATED, USER_LOGIN, etc.)
        description: Human readable description (alias for message)
        message: Human readable message (deprecated, use description)
        severity: 'info', 'warning', or 'critical'
        entity_type: Type of entity (ride, reservation, user, system)
        user_id: Optional related user ID (alias for employee_id)
        employee_id: Optional related employee ID
        ride_id: Optional related ride ID
        reservation_id: Optional related reservation ID
        metadata: Optional JSON metadata dict
        
    Returns:
        SystemEvent instance or None if logging fails
    """
    try:
        # Support both description and message parameters
        msg = description or message or 'System event'
        
        # Support both user_id and employee_id parameters
        emp_id = user_id or employee_id
        
        event = SystemEvent(
            event_type=event_type,
            message=msg,
            severity=severity,
            entity_type=entity_type,
            employee_id=emp_id,
            ride_id=ride_id,
            reservation_id=reservation_id,
            event_metadata=metadata
        )
        db.session.add(event)
        # Don't commit here - let caller handle transaction
        return event
    except Exception as e:
        # Log error but don't break the main transaction
        import logging
        logging.error(f'Failed to log system event {event_type}: {e}')
        return None
