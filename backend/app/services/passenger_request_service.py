from datetime import datetime, timedelta
from math import radians, cos, sin, asin, sqrt
from app.repositories.passenger_request_repository import PassengerRequestRepository
from app.models.system_event import SystemEvent
from app import db


class PassengerRequestService:
    """
    Service layer for managing passenger ride requests.
    Handles business logic for creating and managing requests that will be used
    by the AI matching system.
    """

    # Duplicate detection thresholds
    DUPLICATE_DISTANCE_THRESHOLD_METERS = 200  # 200 meters
    DUPLICATE_TIME_THRESHOLD_MINUTES = 15  # 15 minutes

    @staticmethod
    def _calculate_haversine_distance(lat1, lng1, lat2, lng2):
        """
        Calculate the great circle distance between two points on Earth.
        Uses the Haversine formula.
        
        Args:
            lat1, lng1: Coordinates of first point
            lat2, lng2: Coordinates of second point
            
        Returns:
            float: Distance in meters
        """
        # Convert decimal degrees to radians
        lat1, lng1, lat2, lng2 = map(radians, [lat1, lng1, lat2, lng2])

        # Haversine formula
        dlat = lat2 - lat1
        dlng = lng2 - lng1
        a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlng / 2) ** 2
        c = 2 * asin(sqrt(a))
        
        # Radius of Earth in meters
        r = 6371000
        
        return c * r

    @staticmethod
    def _is_duplicate_request(user_id, origin_lat, origin_lng, destination_lat, 
                             destination_lng, departure_time):
        """
        Check if a similar request already exists for this user.
        
        Duplicate criteria:
        - Same user
        - Origin within 200m
        - Destination within 200m
        - Departure time within 15 minutes
        
        Args:
            user_id: ID of the user
            origin_lat, origin_lng: Origin coordinates
            destination_lat, destination_lng: Destination coordinates
            departure_time: Desired departure time
            
        Returns:
            bool: True if a duplicate exists, False otherwise
        """
        # Get recent requests by this user
        recent_requests = PassengerRequestRepository.find_recent_requests_by_user(
            user_id, 
            time_window_minutes=PassengerRequestService.DUPLICATE_TIME_THRESHOLD_MINUTES
        )
        
        for request in recent_requests:
            # Check origin distance
            origin_distance = PassengerRequestService._calculate_haversine_distance(
                origin_lat, origin_lng,
                request.origin_lat, request.origin_lng
            )
            
            # Check destination distance
            destination_distance = PassengerRequestService._calculate_haversine_distance(
                destination_lat, destination_lng,
                request.destination_lat, request.destination_lng
            )
            
            # Check time difference
            time_diff = abs((departure_time - request.departure_time).total_seconds() / 60)
            
            # If all criteria match, it's a duplicate
            if (origin_distance <= PassengerRequestService.DUPLICATE_DISTANCE_THRESHOLD_METERS and
                destination_distance <= PassengerRequestService.DUPLICATE_DISTANCE_THRESHOLD_METERS and
                time_diff <= PassengerRequestService.DUPLICATE_TIME_THRESHOLD_MINUTES):
                return True
        
        return False

    @staticmethod
    def create_passenger_request_from_search(user_id, origin_lat, origin_lng, 
                                            destination_lat, destination_lng,
                                            departure_time, country):
        """
        Create a passenger request from a failed ride search.
        
        This method:
        1. Checks for duplicate requests
        2. Creates a new request if not duplicate
        3. Logs a system event
        
        Args:
            user_id: ID of the employee making the request
            origin_lat: Latitude of origin point
            origin_lng: Longitude of origin point
            destination_lat: Latitude of destination point
            destination_lng: Longitude of destination point
            departure_time: Desired departure time
            country: Country code (tunisia or france)
            
        Returns:
            dict: Result containing success status and request_id or message
        """
        try:
            # Check for duplicates
            if PassengerRequestService._is_duplicate_request(
                user_id, origin_lat, origin_lng, 
                destination_lat, destination_lng, departure_time
            ):
                return {
                    'success': False,
                    'message': 'Duplicate request detected',
                    'request_id': None
                }
            
            # Create the request
            request = PassengerRequestRepository.create_request(
                user_id=user_id,
                origin_lat=origin_lat,
                origin_lng=origin_lng,
                destination_lat=destination_lat,
                destination_lng=destination_lng,
                departure_time=departure_time,
                country=country
            )
            
            # Log system event
            PassengerRequestService._log_request_created_event(request)
            
            return {
                'success': True,
                'message': 'Passenger request created successfully',
                'request_id': request.id
            }
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Error creating passenger request: {str(e)}',
                'request_id': None
            }

    @staticmethod
    def _log_request_created_event(request):
        """
        Log a system event when a passenger request is created.
        
        Args:
            request: The PassengerRequest object
        """
        try:
            from app.models.system_event import SystemEvent
            event = SystemEvent(
                event_type='PASSENGER_REQUEST_CREATED',
                entity_type='passenger_request',
                message=f'Passenger request created for {request.country}',
                severity='info',
                employee_id=request.user_id,
                event_metadata={
                    'request_id': request.id,
                    'origin': {
                        'lat': request.origin_lat,
                        'lng': request.origin_lng
                    },
                    'destination': {
                        'lat': request.destination_lat,
                        'lng': request.destination_lng
                    },
                    'departure_time': request.departure_time.isoformat(),
                    'country': request.country,
                    'expires_at': request.expires_at.isoformat()
                }
            )
            db.session.add(event)
            db.session.commit()
        except Exception as e:
            # Don't fail the request creation if event logging fails
            db.session.rollback()
            print(f"Warning: Failed to log PASSENGER_REQUEST_CREATED event: {str(e)}")

    @staticmethod
    def expire_old_requests():
        """
        Expire all requests that have passed their expiration time.
        This should be called periodically by a background job.
        
        Returns:
            dict: Result containing count of expired requests
        """
        try:
            count = PassengerRequestRepository.expire_old_requests()
            return {
                'success': True,
                'expired_count': count,
                'message': f'Expired {count} passenger requests'
            }
        except Exception as e:
            return {
                'success': False,
                'expired_count': 0,
                'message': f'Error expiring requests: {str(e)}'
            }

    @staticmethod
    def get_open_requests_by_country(country):
        """
        Get all open passenger requests for a specific country.
        This will be used by the AI matching system.
        
        Args:
            country: Country code to filter by
            
        Returns:
            List[PassengerRequest]: List of open requests
        """
        return PassengerRequestRepository.find_open_requests_by_country(country)

    @staticmethod
    def get_all_open_requests():
        """
        Get all open passenger requests.
        This will be used by the AI matching system.
        
        Returns:
            List[PassengerRequest]: List of all open requests
        """
        return PassengerRequestRepository.find_open_requests()
