from datetime import datetime, timedelta
from app import db


class PassengerRequest(db.Model):
    """
    Model for storing passenger ride search requests when no matching rides are found.
    These requests will be used by the AI matching system to detect route overlaps
    with future driver rides.
    """
    __tablename__ = 'passenger_requests'

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('employees.id', ondelete='CASCADE'), nullable=False)
    origin_lat = db.Column(db.Float, nullable=False)
    origin_lng = db.Column(db.Float, nullable=False)
    destination_lat = db.Column(db.Float, nullable=False)
    destination_lng = db.Column(db.Float, nullable=False)
    departure_time = db.Column(db.DateTime, nullable=False)
    country = db.Column(db.String(50), nullable=False)
    status = db.Column(db.String(20), nullable=False, default='open')
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    expires_at = db.Column(db.DateTime, nullable=False)

    # Relationship
    user = db.relationship('Employee', backref=db.backref('passenger_requests', lazy='dynamic'))

    # Status constants
    STATUS_OPEN = 'open'
    STATUS_MATCHED = 'matched'
    STATUS_EXPIRED = 'expired'

    def __init__(self, user_id, origin_lat, origin_lng, destination_lat, destination_lng,
                 departure_time, country, expires_at=None):
        """
        Initialize a new passenger request.
        
        Args:
            user_id: ID of the employee making the request
            origin_lat: Latitude of origin point
            origin_lng: Longitude of origin point
            destination_lat: Latitude of destination point
            destination_lng: Longitude of destination point
            departure_time: Desired departure time
            country: Country code (tunisia or france)
            expires_at: Optional expiration time (defaults to departure_time + 2 hours)
        """
        self.user_id = user_id
        self.origin_lat = origin_lat
        self.origin_lng = origin_lng
        self.destination_lat = destination_lat
        self.destination_lng = destination_lng
        self.departure_time = departure_time
        self.country = country
        self.status = self.STATUS_OPEN
        self.created_at = datetime.utcnow()
        
        # Default expiration: 2 hours after departure time
        if expires_at is None:
            self.expires_at = departure_time + timedelta(hours=2)
        else:
            self.expires_at = expires_at

        # Validate coordinates
        self._validate_coordinates()

    def _validate_coordinates(self):
        """Validate that coordinates are within valid ranges."""
        if not (-90 <= self.origin_lat <= 90):
            raise ValueError(f"Invalid origin latitude: {self.origin_lat}")
        if not (-180 <= self.origin_lng <= 180):
            raise ValueError(f"Invalid origin longitude: {self.origin_lng}")
        if not (-90 <= self.destination_lat <= 90):
            raise ValueError(f"Invalid destination latitude: {self.destination_lat}")
        if not (-180 <= self.destination_lng <= 180):
            raise ValueError(f"Invalid destination longitude: {self.destination_lng}")

    def mark_as_matched(self):
        """Mark this request as matched with a ride."""
        self.status = self.STATUS_MATCHED

    def mark_as_expired(self):
        """Mark this request as expired."""
        self.status = self.STATUS_EXPIRED

    def is_open(self):
        """Check if this request is still open."""
        return self.status == self.STATUS_OPEN

    def is_expired_by_time(self):
        """Check if this request has passed its expiration time."""
        return datetime.utcnow() > self.expires_at

    def to_dict(self):
        """Convert the request to a dictionary representation."""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'origin': {
                'lat': self.origin_lat,
                'lng': self.origin_lng
            },
            'destination': {
                'lat': self.destination_lat,
                'lng': self.destination_lng
            },
            'departure_time': self.departure_time.isoformat() if self.departure_time else None,
            'country': self.country,
            'status': self.status,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'expires_at': self.expires_at.isoformat() if self.expires_at else None
        }

    def __repr__(self):
        return f'<PassengerRequest {self.id} user={self.user_id} status={self.status}>'
