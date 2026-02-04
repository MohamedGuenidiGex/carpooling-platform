from app.extensions import db

class Notification(db.Model):
    __tablename__ = 'notifications'

    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.Integer, db.ForeignKey('employees.id'), nullable=False)
    ride_id = db.Column(db.Integer, db.ForeignKey('rides.id'), nullable=False)
    message = db.Column(db.Text, nullable=False)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

    # Relationships
    employee = db.relationship('Employee', back_populates='notifications')
    ride = db.relationship('Ride', back_populates='notifications')

    def __repr__(self):
        return f'<Notification for Employee {self.employee_id} about Ride {self.ride_id}>'
