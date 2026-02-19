from app.extensions import db
from datetime import datetime

class SystemEvent(db.Model):
    __tablename__ = 'system_events'

    id = db.Column(db.Integer, primary_key=True)
    event_type = db.Column(db.String(50), nullable=False)
    message = db.Column(db.Text, nullable=False)
    severity = db.Column(db.String(20), nullable=False, default='info')  # info, warning, critical
    employee_id = db.Column(db.Integer, db.ForeignKey('employees.id'), nullable=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('rides.id'), nullable=True)
    reservation_id = db.Column(db.Integer, db.ForeignKey('reservations.id'), nullable=True)
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
            'employee': self.employee.name if self.employee else None,
            'employee_id': self.employee_id,
            'ride_id': self.ride_id,
            'reservation_id': self.reservation_id,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

    def __repr__(self):
        return f'<SystemEvent {self.event_type} {self.severity}>'


def log_system_event(event_type, message, severity='info', employee_id=None, ride_id=None, reservation_id=None):
    """Create a system event log entry.
    
    Args:
        event_type: Type of event (e.g., USER_LOCKED, RIDE_CANCELLED, etc.)
        message: Human readable message
        severity: 'info', 'warning', or 'critical'
        employee_id: Optional related employee ID
        ride_id: Optional related ride ID
        reservation_id: Optional related reservation ID
    """
    event = SystemEvent(
        event_type=event_type,
        message=message,
        severity=severity,
        employee_id=employee_id,
        ride_id=ride_id,
        reservation_id=reservation_id
    )
    db.session.add(event)
    # Don't commit here - let caller handle transaction
    return event
