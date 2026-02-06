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
    status = db.Column(db.String(20), default='ACTIVE')
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    updated_at = db.Column(db.DateTime, server_default=db.func.now(), onupdate=db.func.now())

    # Relationships
    driver = db.relationship('Employee', back_populates='offered_rides')
    reservations = db.relationship('Reservation', back_populates='ride', lazy='dynamic')
    notifications = db.relationship('Notification', back_populates='ride', lazy='dynamic')

    def __repr__(self):
        return f'<Ride {self.origin} to {self.destination} ({self.status})>'
