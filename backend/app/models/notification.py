from app.extensions import db

class Notification(db.Model):
    __tablename__ = 'notifications'

    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.Integer, db.ForeignKey('employees.id'), nullable=False)
    ride_id = db.Column(db.Integer, db.ForeignKey('rides.id'), nullable=True)
    message = db.Column(db.Text, nullable=False)
    type = db.Column(db.String(20), default='info')  # 'request', 'approval', 'rejection', 'cancellation', 'info'
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

    # Relationships
    employee = db.relationship('Employee', back_populates='notifications')
    ride = db.relationship('Ride', back_populates='notifications')

    def to_dict(self):
        """Convert notification to dictionary"""
        return {
            'id': self.id,
            'employee_id': self.employee_id,
            'ride_id': self.ride_id,
            'message': self.message,
            'type': self.type,
            'is_read': self.is_read,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

    def __repr__(self):
        return f'<Notification for Employee {self.employee_id} type={self.type}>'
