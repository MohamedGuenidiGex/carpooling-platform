from app.extensions import db
from werkzeug.security import generate_password_hash, check_password_hash

class Employee(db.Model):
    __tablename__ = 'employees'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    department = db.Column(db.String(100))
    password_hash = db.Column(db.String(256))
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    updated_at = db.Column(db.DateTime, server_default=db.func.now(), onupdate=db.func.now())

    # Carpool profile fields
    phone_number = db.Column(db.String(20))
    car_model = db.Column(db.String(100))
    car_plate = db.Column(db.String(20))
    car_color = db.Column(db.String(50))

    # Relationships
    offered_rides = db.relationship('Ride', back_populates='driver', lazy='dynamic')
    reservations = db.relationship('Reservation', back_populates='employee', lazy='dynamic')
    notifications = db.relationship('Notification', back_populates='employee', lazy='dynamic')

    def set_password(self, password):
        """Hash and set password"""
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        """Verify password against hash"""
        return check_password_hash(self.password_hash, password)

    def to_dict(self, include_stats=False):
        """Convert employee to dictionary"""
        data = {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'department': self.department,
            'phone_number': self.phone_number,
            'car_model': self.car_model,
            'car_plate': self.car_plate,
            'car_color': self.car_color,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
        
        if include_stats:
            data['rides_offered_count'] = self.offered_rides.count()
            data['bookings_count'] = self.reservations.count()
        
        return data

    def __repr__(self):
        return f'<Employee {self.name}>'
