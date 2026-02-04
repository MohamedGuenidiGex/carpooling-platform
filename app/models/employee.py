from app.extensions import db

class Employee(db.Model):
    __tablename__ = 'employees'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    department = db.Column(db.String(100))
    created_at = db.Column(db.DateTime, server_default=db.func.now())
    updated_at = db.Column(db.DateTime, server_default=db.func.now(), onupdate=db.func.now())

    # Relationships
    offered_rides = db.relationship('Ride', back_populates='driver', lazy='dynamic')
    reservations = db.relationship('Reservation', back_populates='employee', lazy='dynamic')
    notifications = db.relationship('Notification', back_populates='employee', lazy='dynamic')

    def __repr__(self):
        return f'<Employee {self.name}>'
