"""
AI Match Repository

Provides data access methods for managing AI-detected ride matches.
"""

from datetime import datetime
from app import db
from app.models.ai_match import AIMatch
from sqlalchemy import and_, or_


class AIMatchRepository:
    """
    Repository layer for AIMatch database operations.
    Handles CRUD operations for AI-detected ride matches.
    """

    @staticmethod
    def create_match(ride_id, passenger_request_id, pickup_lat, pickup_lng,
                    distance_to_route, estimated_detour_minutes, match_score, pickup_name=None):
        """
        Create a new AI match record.
        
        Args:
            ride_id: ID of the driver ride
            passenger_request_id: ID of the passenger request
            pickup_lat: Latitude of suggested pickup point
            pickup_lng: Longitude of suggested pickup point
            distance_to_route: Distance from passenger to route in km
            estimated_detour_minutes: Estimated detour time in minutes
            match_score: Calculated match quality score (0-1)
            pickup_name: Optional human-readable pickup location name
            
        Returns:
            AIMatch: The created match object
            
        Raises:
            Exception: If match already exists or database error occurs
        """
        try:
            match = AIMatch(
                ride_id=ride_id,
                passenger_request_id=passenger_request_id,
                pickup_lat=pickup_lat,
                pickup_lng=pickup_lng,
                distance_to_route=distance_to_route,
                estimated_detour_minutes=estimated_detour_minutes,
                match_score=match_score,
                pickup_name=pickup_name
            )
            
            db.session.add(match)
            db.session.commit()
            
            return match
        except Exception as e:
            db.session.rollback()
            raise e

    @staticmethod
    def get_match_by_id(match_id):
        """
        Get a match by its ID.
        
        Args:
            match_id: ID of the match
            
        Returns:
            AIMatch or None if not found
        """
        return AIMatch.query.get(match_id)

    @staticmethod
    def get_matches_for_passenger(passenger_request_id, status=None):
        """
        Get all matches for a specific passenger request.
        
        Args:
            passenger_request_id: ID of the passenger request
            status: Optional status filter
            
        Returns:
            List[AIMatch]: List of matches
        """
        query = AIMatch.query.filter_by(passenger_request_id=passenger_request_id)
        
        if status:
            query = query.filter_by(status=status)
        
        return query.order_by(AIMatch.match_score.desc()).all()

    @staticmethod
    def get_matches_for_ride(ride_id, status=None):
        """
        Get all matches for a specific ride.
        
        Args:
            ride_id: ID of the ride
            status: Optional status filter
            
        Returns:
            List[AIMatch]: List of matches
        """
        query = AIMatch.query.filter_by(ride_id=ride_id)
        
        if status:
            query = query.filter_by(status=status)
        
        return query.order_by(AIMatch.match_score.desc()).all()

    @staticmethod
    def check_match_exists(ride_id, passenger_request_id):
        """
        Check if a match already exists between a ride and passenger request.
        
        Args:
            ride_id: ID of the ride
            passenger_request_id: ID of the passenger request
            
        Returns:
            AIMatch or None if no match exists
        """
        return AIMatch.query.filter_by(
            ride_id=ride_id,
            passenger_request_id=passenger_request_id
        ).first()

    @staticmethod
    def update_match_status(match_id, new_status):
        """
        Update the status of a match.
        
        Args:
            match_id: ID of the match
            new_status: New status value
            
        Returns:
            AIMatch: Updated match object or None if not found
        """
        try:
            match = AIMatch.query.get(match_id)
            if match:
                match.update_status(new_status)
                db.session.commit()
            return match
        except Exception as e:
            db.session.rollback()
            raise e

    @staticmethod
    def get_suggested_matches(limit=None):
        """
        Get all matches in 'suggested' status.
        
        Args:
            limit: Optional limit on number of results
            
        Returns:
            List[AIMatch]: List of suggested matches
        """
        query = AIMatch.query.filter_by(status=AIMatch.STATUS_SUGGESTED)
        query = query.order_by(AIMatch.match_score.desc())
        
        if limit:
            query = query.limit(limit)
        
        return query.all()

    @staticmethod
    def get_matches_by_score_threshold(min_score, status=None):
        """
        Get matches above a certain score threshold.
        
        Args:
            min_score: Minimum match score
            status: Optional status filter
            
        Returns:
            List[AIMatch]: List of matches
        """
        query = AIMatch.query.filter(AIMatch.match_score >= min_score)
        
        if status:
            query = query.filter_by(status=status)
        
        return query.order_by(AIMatch.match_score.desc()).all()

    @staticmethod
    def delete_match(match_id):
        """
        Delete a match record.
        
        Args:
            match_id: ID of the match to delete
            
        Returns:
            bool: True if deleted, False if not found
        """
        try:
            match = AIMatch.query.get(match_id)
            if match:
                db.session.delete(match)
                db.session.commit()
                return True
            return False
        except Exception as e:
            db.session.rollback()
            raise e

    @staticmethod
    def expire_old_matches(ride_id=None):
        """
        Mark matches as expired for rides that have passed.
        
        Args:
            ride_id: Optional specific ride ID to expire matches for
            
        Returns:
            int: Number of matches expired
        """
        try:
            query = AIMatch.query.filter_by(status=AIMatch.STATUS_SUGGESTED)
            
            if ride_id:
                query = query.filter_by(ride_id=ride_id)
            
            matches = query.all()
            count = 0
            
            for match in matches:
                # Check if the associated ride has passed
                # This would require checking the ride's departure time
                # For now, just update the status
                match.update_status(AIMatch.STATUS_EXPIRED)
                count += 1
            
            if count > 0:
                db.session.commit()
            
            return count
        except Exception as e:
            db.session.rollback()
            raise e

    @staticmethod
    def get_match_statistics():
        """
        Get statistics about AI matches.
        
        Returns:
            Dictionary with match statistics
        """
        total = AIMatch.query.count()
        suggested = AIMatch.query.filter_by(status=AIMatch.STATUS_SUGGESTED).count()
        accepted = AIMatch.query.filter_by(status=AIMatch.STATUS_ACCEPTED).count()
        rejected = AIMatch.query.filter_by(status=AIMatch.STATUS_REJECTED).count()
        expired = AIMatch.query.filter_by(status=AIMatch.STATUS_EXPIRED).count()
        
        avg_score = db.session.query(db.func.avg(AIMatch.match_score)).scalar() or 0
        
        return {
            'total_matches': total,
            'suggested': suggested,
            'accepted': accepted,
            'rejected': rejected,
            'expired': expired,
            'average_score': float(avg_score)
        }
