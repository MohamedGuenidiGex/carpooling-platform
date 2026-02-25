from datetime import datetime
from app.extensions import db

class Ride(db.Model):
    __tablename__ = 'rides'

    id = db.Column(db.Integer, primary_key=True)
    driver_id = db.Column(db.Integer, db.ForeignKey('employees.id'), nullable=False)
    origin = db.Column(db.String(255), nullable=False)
    destination = db.Column(db.String(255), nullable=False)
    departure_time = db.Column(db.DateTime, nullable=False)
    available_seats = db.Column(db.Integer, nullable=False)
    status = db.Column(db.String(20), default='scheduled')
    cancelled_at = db.Column(db.DateTime, nullable=True)
    is_deleted = db.Column(db.Boolean, default=False, nullable=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    updated_at = db.Column(db.DateTime, server_default=db.func.now(), onupdate=db.func.now())

    # Relationships
    driver = db.relationship('Employee', back_populates='offered_rides')
    reservations = db.relationship('Reservation', back_populates='ride', lazy='dynamic')
    notifications = db.relationship('Notification', back_populates='ride', lazy='dynamic')

    # Valid status values
    VALID_STATUSES = [
        'scheduled',
        'driver_en_route',
        'arrived',
        'in_progress',
        'completed',
        'cancelled',
        # Legacy statuses for backward compatibility
        'ACTIVE',
        'FULL'
    ]

    # State transition rules
    VALID_TRANSITIONS = {
        'scheduled': ['driver_en_route', 'cancelled'],
        'ACTIVE': ['driver_en_route', 'cancelled'],  # Legacy support
        'FULL': ['driver_en_route', 'cancelled'],    # Legacy support
        'driver_en_route': ['arrived', 'cancelled'],
        'arrived': ['in_progress', 'cancelled'],
        'in_progress': ['completed', 'cancelled'],
        'completed': [],  # Terminal state
        'cancelled': []   # Terminal state
    }

    def can_transition_to(self, new_status):
        """Check if transition from current status to new status is valid."""
        if new_status not in self.VALID_STATUSES:
            return False
        
        current_status = self.status or 'scheduled'
        allowed_transitions = self.VALID_TRANSITIONS.get(current_status, [])
        return new_status in allowed_transitions

    def __repr__(self):
        return f'<Ride {self.origin} to {self.destination} ({self.status})>'
