"""
AI Match Model

Represents a potential match between a driver ride and a passenger request,
detected by the AI matching engine based on route overlap analysis.
"""

from datetime import datetime
from app import db


class AIMatch(db.Model):
    """
    Model for AI-detected matches between driver rides and passenger requests.
    
    A match is created when the route analysis engine determines that a passenger
    location lies near a driver's route, making it a viable pickup opportunity.
    """
    __tablename__ = 'ai_matches'

    id = db.Column(db.Integer, primary_key=True)
    ride_id = db.Column(db.Integer, db.ForeignKey('rides.id', ondelete='CASCADE'), nullable=False)
    passenger_request_id = db.Column(db.Integer, db.ForeignKey('passenger_requests.id', ondelete='CASCADE'), nullable=False)
    pickup_lat = db.Column(db.Float, nullable=False)
    pickup_lng = db.Column(db.Float, nullable=False)
    pickup_name = db.Column(db.String(255), nullable=True)
    distance_to_route = db.Column(db.Float, nullable=False)
    estimated_detour_minutes = db.Column(db.Float, nullable=False)
    match_score = db.Column(db.Float, nullable=False)
    status = db.Column(db.String(20), nullable=False, default='suggested')
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)

    # Relationships
    ride = db.relationship('Ride', backref=db.backref('ai_matches', lazy='dynamic'))
    passenger_request = db.relationship('PassengerRequest', backref=db.backref('ai_matches', lazy='dynamic'))

    # Status constants
    STATUS_SUGGESTED = 'suggested'
    STATUS_REQUESTED = 'requested'
    STATUS_ACCEPTED = 'accepted'
    STATUS_REJECTED = 'rejected'
    STATUS_EXPIRED = 'expired'

    # Unique constraint to prevent duplicate matches
    __table_args__ = (
        db.UniqueConstraint('ride_id', 'passenger_request_id', name='uq_ride_passenger_match'),
    )

    def __init__(self, ride_id, passenger_request_id, pickup_lat, pickup_lng,
                 distance_to_route, estimated_detour_minutes, match_score, pickup_name=None):
        """
        Initialize a new AI match.
        
        Args:
            ride_id: ID of the driver ride
            passenger_request_id: ID of the passenger request
            pickup_lat: Latitude of suggested pickup point
            pickup_lng: Longitude of suggested pickup point
            distance_to_route: Distance from passenger to route in km
            estimated_detour_minutes: Estimated detour time in minutes
            match_score: Calculated match quality score (0-1)
            pickup_name: Optional human-readable pickup location name
        """
        self.ride_id = ride_id
        self.passenger_request_id = passenger_request_id
        self.pickup_lat = pickup_lat
        self.pickup_lng = pickup_lng
        self.pickup_name = pickup_name
        self.distance_to_route = distance_to_route
        self.estimated_detour_minutes = estimated_detour_minutes
        self.match_score = match_score
        self.status = self.STATUS_SUGGESTED
        self.created_at = datetime.utcnow()

    def update_status(self, new_status):
        """
        Update the match status.
        
        Args:
            new_status: One of the STATUS_* constants
        """
        valid_statuses = [
            self.STATUS_SUGGESTED,
            self.STATUS_REQUESTED,
            self.STATUS_ACCEPTED,
            self.STATUS_REJECTED,
            self.STATUS_EXPIRED
        ]
        
        if new_status not in valid_statuses:
            raise ValueError(f"Invalid status: {new_status}")
        
        self.status = new_status

    def is_suggested(self):
        """Check if match is in suggested state."""
        return self.status == self.STATUS_SUGGESTED

    def is_accepted(self):
        """Check if match has been accepted."""
        return self.status == self.STATUS_ACCEPTED

    def is_rejected(self):
        """Check if match has been rejected."""
        return self.status == self.STATUS_REJECTED

    def is_expired(self):
        """Check if match has expired."""
        return self.status == self.STATUS_EXPIRED

    def to_dict(self):
        """
        Convert the match to a dictionary representation.
        
        Returns:
            Dictionary with all match details
        """
        return {
            'id': self.id,
            'ride_id': self.ride_id,
            'passenger_request_id': self.passenger_request_id,
            'pickup_location': {
                'lat': self.pickup_lat,
                'lng': self.pickup_lng,
                'name': self.pickup_name
            },
            'distance_to_route': self.distance_to_route,
            'estimated_detour_minutes': self.estimated_detour_minutes,
            'match_score': self.match_score,
            'status': self.status,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

    def __repr__(self):
        return f'<AIMatch {self.id} ride={self.ride_id} request={self.passenger_request_id} score={self.match_score:.2f}>'
