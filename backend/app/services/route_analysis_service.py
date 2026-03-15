"""
Route Analysis Service for AI-based Ride Matching System.

This service provides route overlap detection capabilities to determine
if a passenger location lies near a driver's route. This enables the AI
matching system to detect potential ride shares.

Key Features:
- Polyline decoding (OSRM format)
- Route point sampling for performance
- Distance calculation from point to route
- Detour time estimation
- Route overlap detection with configurable thresholds
"""

from typing import List, Tuple, Dict, Optional
from app.utils.geo import haversine_distance
import math


class RouteAnalysisService:
    """
    Service for analyzing route overlaps between driver routes and passenger requests.
    """
    
    # Configuration constants
    SAMPLING_DISTANCE_KM = 0.2  # Sample route points every 200 meters
    MAX_OVERLAP_DISTANCE_KM = 1.0  # Maximum distance to route for valid overlap
    MAX_DETOUR_MINUTES = 3.0  # Maximum acceptable detour time
    AVERAGE_SPEED_KMH = 50.0  # Average driving speed for detour estimation
    BOUNDING_BOX_RADIUS_KM = 2.0  # Spatial filter radius
    
    @staticmethod
    def decode_polyline(encoded: str, precision: int = 5) -> List[Tuple[float, float]]:
        """
        Decode an OSRM polyline string into a list of (lat, lng) coordinates.
        
        Uses the Polyline Algorithm Format (https://developers.google.com/maps/documentation/utilities/polylinealgorithm)
        
        Args:
            encoded: Encoded polyline string from OSRM
            precision: Decimal precision (default 5 for OSRM, 6 for Google)
            
        Returns:
            List of (latitude, longitude) tuples
            
        Example:
            >>> decode_polyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
            [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]
        """
        coordinates = []
        index = 0
        lat = 0
        lng = 0
        
        while index < len(encoded):
            # Decode latitude
            result = 0
            shift = 0
            while True:
                b = ord(encoded[index]) - 63
                index += 1
                result |= (b & 0x1f) << shift
                shift += 5
                if b < 0x20:
                    break
            
            dlat = ~(result >> 1) if (result & 1) else (result >> 1)
            lat += dlat
            
            # Decode longitude
            result = 0
            shift = 0
            while True:
                b = ord(encoded[index]) - 63
                index += 1
                result |= (b & 0x1f) << shift
                shift += 5
                if b < 0x20:
                    break
            
            dlng = ~(result >> 1) if (result & 1) else (result >> 1)
            lng += dlng
            
            # Convert to decimal degrees
            coordinates.append((
                lat / (10 ** precision),
                lng / (10 ** precision)
            ))
        
        return coordinates
    
    @staticmethod
    def sample_route_points(route_points: List[Tuple[float, float]], 
                           sampling_distance_km: float = None) -> List[Tuple[float, float]]:
        """
        Sample route points to reduce computational complexity.
        
        Instead of analyzing every coordinate, sample points at regular intervals
        (approximately every 200 meters by default).
        
        Args:
            route_points: List of (lat, lng) tuples representing the route
            sampling_distance_km: Distance between samples in km (default: 0.2 km)
            
        Returns:
            Sampled list of (lat, lng) tuples
            
        Example:
            >>> route = [(36.8, 10.1), (36.81, 10.11), (36.82, 10.12), ...]
            >>> sampled = sample_route_points(route, 0.2)
            >>> len(sampled) < len(route)  # Fewer points
            True
        """
        if not route_points:
            return []
        
        if sampling_distance_km is None:
            sampling_distance_km = RouteAnalysisService.SAMPLING_DISTANCE_KM
        
        # Always include first point
        sampled = [route_points[0]]
        
        if len(route_points) == 1:
            return sampled
        
        cumulative_distance = 0.0
        last_sampled_idx = 0
        
        for i in range(1, len(route_points)):
            # Calculate distance from previous point
            lat1, lng1 = route_points[i - 1]
            lat2, lng2 = route_points[i]
            segment_distance = haversine_distance(lat1, lng1, lat2, lng2)
            
            cumulative_distance += segment_distance
            
            # Sample if we've traveled the sampling distance
            if cumulative_distance >= sampling_distance_km:
                sampled.append(route_points[i])
                cumulative_distance = 0.0
                last_sampled_idx = i
        
        # Always include last point if not already sampled
        if last_sampled_idx != len(route_points) - 1:
            sampled.append(route_points[-1])
        
        return sampled
    
    @staticmethod
    def _create_bounding_box(lat: float, lng: float, radius_km: float) -> Dict[str, float]:
        """
        Create a bounding box around a point for spatial filtering.
        
        Args:
            lat: Center latitude
            lng: Center longitude
            radius_km: Radius in kilometers
            
        Returns:
            Dictionary with min_lat, max_lat, min_lng, max_lng
        """
        # Approximate degrees per km (varies by latitude)
        # At equator: 1 degree ≈ 111 km
        # This is a simplified calculation for small distances
        lat_delta = radius_km / 111.0
        lng_delta = radius_km / (111.0 * math.cos(math.radians(lat)))
        
        return {
            'min_lat': lat - lat_delta,
            'max_lat': lat + lat_delta,
            'min_lng': lng - lng_delta,
            'max_lng': lng + lng_delta
        }
    
    @staticmethod
    def _is_point_in_bounding_box(point: Tuple[float, float], 
                                   bbox: Dict[str, float]) -> bool:
        """
        Check if a point is within a bounding box.
        
        Args:
            point: (lat, lng) tuple
            bbox: Bounding box dictionary
            
        Returns:
            True if point is inside the box
        """
        lat, lng = point
        return (bbox['min_lat'] <= lat <= bbox['max_lat'] and
                bbox['min_lng'] <= lng <= bbox['max_lng'])
    
    @staticmethod
    def distance_point_to_route(passenger_point: Tuple[float, float],
                               route_points: List[Tuple[float, float]]) -> Dict[str, any]:
        """
        Calculate the minimum distance from a passenger location to a driver route.
        
        Uses spatial filtering (bounding box) for performance optimization.
        
        Args:
            passenger_point: (lat, lng) of passenger location
            route_points: List of (lat, lng) tuples representing the route
            
        Returns:
            Dictionary containing:
                - closest_distance: Minimum distance in km
                - closest_point: (lat, lng) of nearest route point
                - closest_index: Index of nearest point in route
                
        Example:
            >>> passenger = (36.82, 10.15)
            >>> route = [(36.8, 10.1), (36.81, 10.12), (36.83, 10.18)]
            >>> result = distance_point_to_route(passenger, route)
            >>> result['closest_distance'] < 1.0
            True
        """
        if not route_points:
            return {
                'closest_distance': float('inf'),
                'closest_point': None,
                'closest_index': -1
            }
        
        passenger_lat, passenger_lng = passenger_point
        
        # Create bounding box for spatial filtering
        bbox = RouteAnalysisService._create_bounding_box(
            passenger_lat, passenger_lng,
            RouteAnalysisService.BOUNDING_BOX_RADIUS_KM
        )
        
        min_distance = float('inf')
        closest_point = None
        closest_index = -1
        points_checked = 0
        
        for idx, route_point in enumerate(route_points):
            # Skip points outside bounding box for performance
            if not RouteAnalysisService._is_point_in_bounding_box(route_point, bbox):
                continue
            
            points_checked += 1
            route_lat, route_lng = route_point
            distance = haversine_distance(
                passenger_lat, passenger_lng,
                route_lat, route_lng
            )
            
            if distance < min_distance:
                min_distance = distance
                closest_point = route_point
                closest_index = idx
        
        # If no points were in bounding box, check all points (fallback)
        if points_checked == 0:
            for idx, route_point in enumerate(route_points):
                route_lat, route_lng = route_point
                distance = haversine_distance(
                    passenger_lat, passenger_lng,
                    route_lat, route_lng
                )
                
                if distance < min_distance:
                    min_distance = distance
                    closest_point = route_point
                    closest_index = idx
        
        return {
            'closest_distance': min_distance,
            'closest_point': closest_point,
            'closest_index': closest_index
        }
    
    @staticmethod
    def estimate_detour_time(passenger_point: Tuple[float, float],
                            closest_route_point: Tuple[float, float],
                            average_speed_kmh: float = None) -> float:
        """
        Estimate the time required for a detour to pick up the passenger.
        
        Simplified calculation:
        - Detour distance ≈ distance to route × 2 (go to passenger and return)
        - Convert distance to time using average driving speed
        
        Args:
            passenger_point: (lat, lng) of passenger location
            closest_route_point: (lat, lng) of nearest point on route
            average_speed_kmh: Average driving speed (default: 50 km/h)
            
        Returns:
            Estimated detour time in minutes
            
        Example:
            >>> passenger = (36.82, 10.15)
            >>> route_point = (36.81, 10.12)
            >>> detour_time = estimate_detour_time(passenger, route_point)
            >>> 0 < detour_time < 10  # Should be a few minutes
            True
        """
        if average_speed_kmh is None:
            average_speed_kmh = RouteAnalysisService.AVERAGE_SPEED_KMH
        
        passenger_lat, passenger_lng = passenger_point
        route_lat, route_lng = closest_route_point
        
        # Calculate one-way distance
        one_way_distance = haversine_distance(
            passenger_lat, passenger_lng,
            route_lat, route_lng
        )
        
        # Detour is approximately twice the distance (go and return)
        detour_distance_km = one_way_distance * 2
        
        # Convert to time: time = distance / speed (result in hours)
        detour_time_hours = detour_distance_km / average_speed_kmh
        
        # Convert to minutes
        detour_time_minutes = detour_time_hours * 60
        
        return detour_time_minutes
    
    @staticmethod
    def check_route_overlap(passenger_point: Tuple[float, float],
                           route_polyline: str = None,
                           route_points: List[Tuple[float, float]] = None,
                           max_distance_km: float = None,
                           max_detour_minutes: float = None) -> Dict[str, any]:
        """
        Determine if a passenger location has a valid overlap with a driver route.
        
        A valid overlap requires:
        - Distance to route ≤ max_distance_km (default: 1 km)
        - Estimated detour ≤ max_detour_minutes (default: 3 minutes)
        
        Args:
            passenger_point: (lat, lng) of passenger location
            route_polyline: Encoded OSRM polyline (optional if route_points provided)
            route_points: Pre-decoded route points (optional if route_polyline provided)
            max_distance_km: Maximum acceptable distance (default: 1.0 km)
            max_detour_minutes: Maximum acceptable detour (default: 3.0 minutes)
            
        Returns:
            Dictionary containing:
                - is_overlap: Boolean indicating if valid overlap exists
                - distance_to_route: Distance in km
                - closest_point: (lat, lng) of nearest route point
                - estimated_detour: Detour time in minutes
                - meets_distance_threshold: Boolean
                - meets_detour_threshold: Boolean
                
        Example:
            >>> passenger = (36.82, 10.15)
            >>> route = "_p~iF~ps|U_ulLnnqC"  # Encoded polyline
            >>> result = check_route_overlap(passenger, route_polyline=route)
            >>> result['is_overlap']  # True or False
            True
        """
        if max_distance_km is None:
            max_distance_km = RouteAnalysisService.MAX_OVERLAP_DISTANCE_KM
        
        if max_detour_minutes is None:
            max_detour_minutes = RouteAnalysisService.MAX_DETOUR_MINUTES
        
        # Decode polyline if provided
        if route_points is None:
            if route_polyline is None:
                raise ValueError("Either route_polyline or route_points must be provided")
            route_points = RouteAnalysisService.decode_polyline(route_polyline)
        
        # Sample route points for performance
        sampled_points = RouteAnalysisService.sample_route_points(route_points)
        
        # Calculate distance to route
        distance_result = RouteAnalysisService.distance_point_to_route(
            passenger_point,
            sampled_points
        )
        
        distance_to_route = distance_result['closest_distance']
        closest_point = distance_result['closest_point']
        
        # Check distance threshold
        meets_distance_threshold = distance_to_route <= max_distance_km
        
        # Estimate detour time
        estimated_detour = 0.0
        meets_detour_threshold = False
        
        if closest_point is not None:
            estimated_detour = RouteAnalysisService.estimate_detour_time(
                passenger_point,
                closest_point
            )
            meets_detour_threshold = estimated_detour <= max_detour_minutes
        
        # Valid overlap if both thresholds are met
        is_overlap = meets_distance_threshold and meets_detour_threshold
        
        return {
            'is_overlap': is_overlap,
            'distance_to_route': distance_to_route,
            'closest_point': closest_point,
            'estimated_detour': estimated_detour,
            'meets_distance_threshold': meets_distance_threshold,
            'meets_detour_threshold': meets_detour_threshold
        }
