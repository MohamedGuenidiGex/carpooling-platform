"""
AI Matching Service

Intelligent matching engine that connects passenger requests with driver rides
based on route overlap analysis and multi-factor scoring.
"""

from typing import List, Dict, Optional
from datetime import datetime, timedelta
from app.utils.geo import haversine_distance
from app.services.route_analysis_service import RouteAnalysisService
from app.services.ai_notification_service import AINotificationService
from app.repositories.ai_match_repository import AIMatchRepository
from app.repositories.passenger_request_repository import PassengerRequestRepository
from app.models.passenger_request import PassengerRequest
from app.models import Ride
import logging

logger = logging.getLogger(__name__)


class AIMatchingService:
    """
    Service for detecting and scoring matches between driver rides and passenger requests.
    
    Uses route overlap detection and multi-factor scoring to identify viable ride shares.
    """
    
    # Configuration constants
    MIN_MATCH_SCORE = 0.6  # Minimum score to create a match (60%)
    
    # Scoring weights (must sum to 1.0)
    WEIGHT_PICKUP_PROXIMITY = 0.4
    WEIGHT_DESTINATION_SIMILARITY = 0.3
    WEIGHT_TIME_COMPATIBILITY = 0.2
    WEIGHT_SEAT_AVAILABILITY = 0.1
    
    # Time compatibility window
    MAX_TIME_DIFFERENCE_HOURS = 2.0  # Accept requests within 2 hours of ride time
    
    @staticmethod
    def calculate_match_score(ride: Ride, passenger_request: PassengerRequest,
                             overlap_result: Dict) -> float:
        """
        Calculate a match quality score based on multiple factors.
        
        Scoring formula:
        - 40% pickup proximity (closer is better)
        - 30% destination similarity (closer destinations score higher)
        - 20% departure time compatibility (closer times score higher)
        - 10% seat availability (more seats score higher)
        
        Args:
            ride: The driver ride
            passenger_request: The passenger request
            overlap_result: Result from RouteAnalysisService.check_route_overlap()
            
        Returns:
            float: Match score between 0 and 1
        """
        scores = {}
        
        # 1. Pickup Proximity Score (0-1)
        # Based on distance to route and detour time
        distance_km = overlap_result['distance_to_route']
        detour_min = overlap_result['estimated_detour']
        
        # Normalize distance: 0km = 1.0, 1km = 0.0
        distance_score = max(0, 1 - (distance_km / 1.0))
        
        # Normalize detour: 0min = 1.0, 3min = 0.0
        detour_score = max(0, 1 - (detour_min / 3.0))
        
        # Average of distance and detour scores
        scores['pickup_proximity'] = (distance_score + detour_score) / 2
        
        # 2. Destination Similarity Score (0-1)
        # How close are the destinations?
        if ride.destination_lat and ride.destination_lng:
            dest_distance = haversine_distance(
                passenger_request.destination_lat,
                passenger_request.destination_lng,
                ride.destination_lat,
                ride.destination_lng
            )
            # Normalize: 0km = 1.0, 5km = 0.0
            scores['destination_similarity'] = max(0, 1 - (dest_distance / 5.0))
        else:
            scores['destination_similarity'] = 0.5  # Default if no coordinates
        
        # 3. Time Compatibility Score (0-1)
        # How close are the departure times?
        time_diff = abs((ride.departure_time - passenger_request.departure_time).total_seconds() / 3600)
        # Normalize: 0h = 1.0, 2h = 0.0
        scores['time_compatibility'] = max(0, 1 - (time_diff / AIMatchingService.MAX_TIME_DIFFERENCE_HOURS))
        
        # 4. Seat Availability Score (0-1)
        # More available seats = higher score
        if ride.available_seats > 0:
            # Normalize: 1 seat = 0.5, 4+ seats = 1.0
            scores['seat_availability'] = min(1.0, 0.25 + (ride.available_seats * 0.25))
        else:
            scores['seat_availability'] = 0.0
        
        # Calculate weighted total score
        total_score = (
            scores['pickup_proximity'] * AIMatchingService.WEIGHT_PICKUP_PROXIMITY +
            scores['destination_similarity'] * AIMatchingService.WEIGHT_DESTINATION_SIMILARITY +
            scores['time_compatibility'] * AIMatchingService.WEIGHT_TIME_COMPATIBILITY +
            scores['seat_availability'] * AIMatchingService.WEIGHT_SEAT_AVAILABILITY
        )
        
        return total_score

    @staticmethod
    def process_new_ride(ride: Ride) -> List[Dict]:
        """
        Process a newly created ride to find matching passenger requests.
        
        Workflow:
        1. Get all open passenger requests in the same country
        2. For each request, check route overlap
        3. If overlap exists, calculate match score
        4. If score >= threshold, create AI match record
        
        Args:
            ride: The newly created ride
            
        Returns:
            List of created match dictionaries
        """
        matches_created = []
        
        try:
            # Validate ride has required data
            if not ride.origin_lat or not ride.origin_lng or not ride.destination_lat or not ride.destination_lng:
                logger.warning(f"Ride {ride.id} missing coordinates, skipping AI matching")
                return matches_created
            
            # Determine country from ride coordinates
            # Tunisia: roughly 30-38°N, 7-12°E
            # France: roughly 41-51°N, -5-10°E
            if 30 <= ride.origin_lat <= 38 and 7 <= ride.origin_lng <= 12:
                country = 'tunisia'
            elif 41 <= ride.origin_lat <= 51 and -5 <= ride.origin_lng <= 10:
                country = 'france'
            else:
                country = 'tunisia'  # Default
            
            # Get open passenger requests in the same country
            passenger_requests = PassengerRequestRepository.find_open_requests_by_country(country)
            
            logger.info(f"Processing ride {ride.id}: found {len(passenger_requests)} open requests in {country}")
            
            # Build route for overlap detection
            route_points = [
                (ride.origin_lat, ride.origin_lng),
                (ride.destination_lat, ride.destination_lng)
            ]
            
            for request in passenger_requests:
                try:
                    # Check if match already exists
                    existing_match = AIMatchRepository.check_match_exists(ride.id, request.id)
                    if existing_match:
                        logger.debug(f"Match already exists: ride {ride.id} + request {request.id}")
                        continue
                    
                    # Check route overlap
                    passenger_point = (request.origin_lat, request.origin_lng)
                    overlap_result = RouteAnalysisService.check_route_overlap(
                        passenger_point,
                        route_points=route_points
                    )
                    
                    if not overlap_result['is_overlap']:
                        continue
                    
                    # Calculate match score
                    match_score = AIMatchingService.calculate_match_score(
                        ride, request, overlap_result
                    )
                    
                    # Only create match if score meets threshold
                    if match_score < AIMatchingService.MIN_MATCH_SCORE:
                        logger.debug(f"Match score {match_score:.2f} below threshold for ride {ride.id} + request {request.id}")
                        continue
                    
                    # Create AI match record
                    # Resolve pickup_name using reverse geocoding
                    try:
                        from app.services.geocoding_service import GeocodingService
                        pickup_name = GeocodingService.get_location_name_with_fallback(
                            overlap_result['closest_point'][0],
                            overlap_result['closest_point'][1]
                        )
                    except Exception as geo_error:
                        logger.warning(f"Reverse geocoding failed: {geo_error}, using coordinates")
                        pickup_name = f"Near {overlap_result['closest_point'][0]:.4f}, {overlap_result['closest_point'][1]:.4f}"
                    
                    match = AIMatchRepository.create_match(
                        ride_id=ride.id,
                        passenger_request_id=request.id,
                        pickup_lat=overlap_result['closest_point'][0],
                        pickup_lng=overlap_result['closest_point'][1],
                        distance_to_route=overlap_result['distance_to_route'],
                        estimated_detour_minutes=overlap_result['estimated_detour'],
                        match_score=match_score,
                        pickup_name=pickup_name
                    )
                    
                    matches_created.append(match.to_dict())
                    logger.info(f"Created match {match.id}: ride {ride.id} + request {request.id}, score {match_score:.2f}")
                    
                    # Send notification to passenger
                    try:
                        AINotificationService.notify_passenger_match(match)
                    except Exception as notif_error:
                        logger.error(f"Failed to send notification for match {match.id}: {notif_error}")
                    
                except Exception as e:
                    logger.error(f"Error processing request {request.id} for ride {ride.id}: {e}")
                    continue
            
            logger.info(f"Ride {ride.id}: created {len(matches_created)} matches")
            
        except Exception as e:
            logger.error(f"Error in process_new_ride for ride {ride.id}: {e}")
        
        return matches_created

    @staticmethod
    def process_passenger_request(passenger_request: PassengerRequest) -> List[Dict]:
        """
        Process a newly created passenger request to find matching rides.
        
        Workflow:
        1. Get candidate rides (same country, upcoming, available seats)
        2. For each ride, check route overlap
        3. If overlap exists, calculate match score
        4. If score >= threshold, create AI match record
        
        Args:
            passenger_request: The newly created passenger request
            
        Returns:
            List of created match dictionaries
        """
        matches_created = []
        
        try:
            from app.models import Ride
            from datetime import datetime, timedelta
            
            # Get candidate rides
            # Filter: same country, upcoming (within time window), not completed/cancelled
            time_window_start = passenger_request.departure_time - timedelta(hours=AIMatchingService.MAX_TIME_DIFFERENCE_HOURS)
            time_window_end = passenger_request.departure_time + timedelta(hours=AIMatchingService.MAX_TIME_DIFFERENCE_HOURS)
            
            # Query rides in time window with available seats
            candidate_rides = Ride.query.filter(
                Ride.departure_time >= time_window_start,
                Ride.departure_time <= time_window_end,
                Ride.available_seats > 0,
                Ride.status.notin_(['completed', 'cancelled', 'missed']),
                Ride.is_deleted == False
            ).all()
            
            logger.info(f"Processing request {passenger_request.id}: found {len(candidate_rides)} candidate rides")
            
            passenger_point = (passenger_request.origin_lat, passenger_request.origin_lng)
            
            for ride in candidate_rides:
                try:
                    # Validate ride has coordinates
                    if not ride.origin_lat or not ride.origin_lng or not ride.destination_lat or not ride.destination_lng:
                        continue
                    
                    # Check if match already exists
                    existing_match = AIMatchRepository.check_match_exists(ride.id, passenger_request.id)
                    if existing_match:
                        logger.debug(f"Match already exists: ride {ride.id} + request {passenger_request.id}")
                        continue
                    
                    # Build route
                    route_points = [
                        (ride.origin_lat, ride.origin_lng),
                        (ride.destination_lat, ride.destination_lng)
                    ]
                    
                    # Check route overlap
                    overlap_result = RouteAnalysisService.check_route_overlap(
                        passenger_point,
                        route_points=route_points
                    )
                    
                    if not overlap_result['is_overlap']:
                        continue
                    
                    # Calculate match score
                    match_score = AIMatchingService.calculate_match_score(
                        ride, passenger_request, overlap_result
                    )
                    
                    # Only create match if score meets threshold
                    if match_score < AIMatchingService.MIN_MATCH_SCORE:
                        logger.debug(f"Match score {match_score:.2f} below threshold for ride {ride.id} + request {passenger_request.id}")
                        continue
                    
                    # Create AI match record
                    # Resolve pickup_name using reverse geocoding
                    try:
                        from app.services.geocoding_service import GeocodingService
                        pickup_name = GeocodingService.get_location_name_with_fallback(
                            overlap_result['closest_point'][0],
                            overlap_result['closest_point'][1]
                        )
                    except Exception as geo_error:
                        logger.warning(f"Reverse geocoding failed: {geo_error}, using coordinates")
                        pickup_name = f"Near {overlap_result['closest_point'][0]:.4f}, {overlap_result['closest_point'][1]:.4f}"
                    
                    match = AIMatchRepository.create_match(
                        ride_id=ride.id,
                        passenger_request_id=passenger_request.id,
                        pickup_lat=overlap_result['closest_point'][0],
                        pickup_lng=overlap_result['closest_point'][1],
                        distance_to_route=overlap_result['distance_to_route'],
                        estimated_detour_minutes=overlap_result['estimated_detour'],
                        match_score=match_score,
                        pickup_name=pickup_name
                    )
                    
                    matches_created.append(match.to_dict())
                    logger.info(f"Created match {match.id}: ride {ride.id} + request {passenger_request.id}, score {match_score:.2f}")
                    
                    # Send notification to passenger
                    try:
                        AINotificationService.notify_passenger_match(match)
                    except Exception as notif_error:
                        logger.error(f"Failed to send notification for match {match.id}: {notif_error}")
                    
                except Exception as e:
                    logger.error(f"Error processing ride {ride.id} for request {passenger_request.id}: {e}")
                    continue
            
            logger.info(f"Request {passenger_request.id}: created {len(matches_created)} matches")
            
        except Exception as e:
            logger.error(f"Error in process_passenger_request for request {passenger_request.id}: {e}")
        
        return matches_created

    @staticmethod
    def get_match_details(match_id: int) -> Optional[Dict]:
        """
        Get detailed information about a match including ride and request details.
        
        Args:
            match_id: ID of the match
            
        Returns:
            Dictionary with match, ride, and request details or None
        """
        match = AIMatchRepository.get_match_by_id(match_id)
        if not match:
            return None
        
        return {
            'match': match.to_dict(),
            'ride': match.ride.to_dict() if match.ride else None,
            'passenger_request': match.passenger_request.to_dict() if match.passenger_request else None
        }

    @staticmethod
    def get_matches_for_passenger_user(user_id: int) -> List[Dict]:
        """
        Get all AI matches for a specific passenger (user).
        
        Args:
            user_id: ID of the passenger user
            
        Returns:
            List of match dictionaries with ride details
        """
        # Get all passenger requests for this user
        passenger_requests = PassengerRequest.query.filter_by(user_id=user_id).all()
        
        all_matches = []
        for request in passenger_requests:
            matches = AIMatchRepository.get_matches_for_passenger(request.id)
            for match in matches:
                match_dict = match.to_dict()
                match_dict['ride_details'] = match.ride.to_dict() if match.ride else None
                all_matches.append(match_dict)
        
        # Sort by score descending
        all_matches.sort(key=lambda x: x['match_score'], reverse=True)
        
        return all_matches
