from datetime import datetime
from app import db
from app.models.passenger_request import PassengerRequest
from sqlalchemy import and_


class PassengerRequestRepository:
    """
    Repository layer for PassengerRequest database operations.
    Provides data access methods for managing passenger ride requests.
    """

    @staticmethod
    def create_request(user_id, origin_lat, origin_lng, destination_lat, destination_lng,
                      departure_time, country, expires_at=None):
        """
        Create a new passenger request.
        
        Args:
            user_id: ID of the employee making the request
            origin_lat: Latitude of origin point
            origin_lng: Longitude of origin point
            destination_lat: Latitude of destination point
            destination_lng: Longitude of destination point
            departure_time: Desired departure time
            country: Country code (tunisia or france)
            expires_at: Optional expiration time
            
        Returns:
            PassengerRequest: The created request object
        """
        try:
            request = PassengerRequest(
                user_id=user_id,
                origin_lat=origin_lat,
                origin_lng=origin_lng,
                destination_lat=destination_lat,
                destination_lng=destination_lng,
                departure_time=departure_time,
                country=country,
                expires_at=expires_at
            )
            
            db.session.add(request)
            db.session.commit()
            
            return request
        except Exception as e:
            db.session.rollback()
            raise e

    @staticmethod
    def find_open_requests():
        """
        Find all open passenger requests.
        
        Returns:
            List[PassengerRequest]: List of open requests
        """
        return PassengerRequest.query.filter_by(
            status=PassengerRequest.STATUS_OPEN
        ).order_by(PassengerRequest.created_at.desc()).all()

    @staticmethod
    def find_open_requests_by_country(country):
        """
        Find all open passenger requests for a specific country.
        
        Args:
            country: Country code to filter by
            
        Returns:
            List[PassengerRequest]: List of open requests in the specified country
        """
        return PassengerRequest.query.filter_by(
            status=PassengerRequest.STATUS_OPEN,
            country=country
        ).order_by(PassengerRequest.created_at.desc()).all()

    @staticmethod
    def find_recent_requests_by_user(user_id, time_window_minutes=15):
        """
        Find recent requests by a specific user within a time window.
        Used for duplicate detection.
        
        Args:
            user_id: ID of the user
            time_window_minutes: Time window in minutes to look back
            
        Returns:
            List[PassengerRequest]: List of recent requests by the user
        """
        from datetime import timedelta
        cutoff_time = datetime.utcnow() - timedelta(minutes=time_window_minutes)
        
        return PassengerRequest.query.filter(
            and_(
                PassengerRequest.user_id == user_id,
                PassengerRequest.created_at >= cutoff_time,
                PassengerRequest.status == PassengerRequest.STATUS_OPEN
            )
        ).all()

    @staticmethod
    def expire_old_requests():
        """
        Mark all requests that have passed their expiration time as expired.
        This should be called periodically by a background job.
        
        Returns:
            int: Number of requests that were expired
        """
        try:
            now = datetime.utcnow()
            
            expired_requests = PassengerRequest.query.filter(
                and_(
                    PassengerRequest.status == PassengerRequest.STATUS_OPEN,
                    PassengerRequest.expires_at <= now
                )
            ).all()
            
            count = 0
            for request in expired_requests:
                request.mark_as_expired()
                count += 1
            
            if count > 0:
                db.session.commit()
            
            return count
        except Exception as e:
            db.session.rollback()
            raise e

    @staticmethod
    def get_by_id(request_id):
        """
        Get a passenger request by ID.
        
        Args:
            request_id: ID of the request
            
        Returns:
            PassengerRequest: The request object or None if not found
        """
        return PassengerRequest.query.get(request_id)

    @staticmethod
    def mark_as_matched(request_id):
        """
        Mark a request as matched.
        
        Args:
            request_id: ID of the request to mark as matched
            
        Returns:
            PassengerRequest: The updated request object or None if not found
        """
        try:
            request = PassengerRequest.query.get(request_id)
            if request:
                request.mark_as_matched()
                db.session.commit()
            return request
        except Exception as e:
            db.session.rollback()
            raise e

    @staticmethod
    def delete_request(request_id):
        """
        Delete a passenger request.
        
        Args:
            request_id: ID of the request to delete
            
        Returns:
            bool: True if deleted, False if not found
        """
        try:
            request = PassengerRequest.query.get(request_id)
            if request:
                db.session.delete(request)
                db.session.commit()
                return True
            return False
        except Exception as e:
            db.session.rollback()
            raise e
