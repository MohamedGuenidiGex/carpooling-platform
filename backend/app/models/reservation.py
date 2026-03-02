from app.extensions import db

class Reservation(db.Model):
    __tablename__ = 'reservations'

    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.Integer, db.ForeignKey('employees.id'), nullable=False)
    ride_id = db.Column(db.Integer, db.ForeignKey('rides.id'), nullable=False)
    seats_reserved = db.Column(db.Integer, nullable=False)
    status = db.Column(db.String(20), nullable=False, default='confirmed')
    boarding_deadline = db.Column(db.DateTime, nullable=True)  # Set when ride arrives
    boarded = db.Column(db.Boolean, default=False, nullable=False)  # True when passenger confirms boarding
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    updated_at = db.Column(db.DateTime, server_default=db.func.now(), onupdate=db.func.now())

    # Relationships
    employee = db.relationship('Employee', back_populates='reservations')
    ride = db.relationship('Ride', back_populates='reservations')

    # Valid reservation statuses
    VALID_STATUSES = ['PENDING', 'CONFIRMED', 'CANCELLED', 'REJECTED', 'MISSED']
    
    # Terminal statuses (cannot transition from these)
    TERMINAL_STATUSES = ['CANCELLED', 'REJECTED', 'MISSED']

    def __repr__(self):
        return f'<Reservation {self.seats_reserved} seats on Ride {self.ride_id}>'
