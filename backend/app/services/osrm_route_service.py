"""
OSRM Route Service

Handles route calculation and recalculation using OSRM API.
Supports dynamic pickup point integration.
"""

import requests
import logging
from typing import Dict, List, Tuple, Optional

logger = logging.getLogger(__name__)


class OSRMRouteService:
    """
    Service for calculating routes using OSRM (Open Source Routing Machine).
    """
    
    # OSRM server URL (can be configured)
    OSRM_SERVER = "http://router.project-osrm.org"
    
    @staticmethod
    def get_route(origin: Tuple[float, float], destination: Tuple[float, float]) -> Optional[Dict]:
        """
        Get route from origin to destination using OSRM.
        
        Args:
            origin: (lat, lng) tuple for origin
            destination: (lat, lng) tuple for destination
            
        Returns:
            Dictionary with route details including polyline, or None if failed
        """
        try:
            # OSRM expects coordinates as lng,lat (not lat,lng)
            origin_lng, origin_lat = origin[1], origin[0]
            dest_lng, dest_lat = destination[1], destination[0]
            
            # Build OSRM route URL
            url = f"{OSRMRouteService.OSRM_SERVER}/route/v1/driving/{origin_lng},{origin_lat};{dest_lng},{dest_lat}"
            params = {
                'overview': 'full',
                'geometries': 'polyline'
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get('code') == 'Ok' and data.get('routes'):
                route = data['routes'][0]
                return {
                    'polyline': route['geometry'],
                    'distance': route['distance'],  # meters
                    'duration': route['duration']   # seconds
                }
            else:
                logger.error(f"OSRM returned error: {data.get('code')}")
                return None
                
        except requests.RequestException as e:
            logger.error(f"OSRM API request failed: {e}")
            return None
        except Exception as e:
            logger.error(f"Error getting OSRM route: {e}")
            return None
    
    @staticmethod
    def recalculate_route_with_pickup(
        origin: Tuple[float, float],
        pickup: Tuple[float, float],
        destination: Tuple[float, float]
    ) -> Optional[Dict]:
        """
        Recalculate route with dynamic pickup point.
        
        Creates route: origin → pickup → destination
        Merges the two route segments into a single polyline.
        
        Args:
            origin: (lat, lng) tuple for ride origin
            pickup: (lat, lng) tuple for dynamic pickup point
            destination: (lat, lng) tuple for ride destination
            
        Returns:
            Dictionary with merged route details, or None if failed
        """
        try:
            logger.info(f"Recalculating route: origin→pickup→destination")
            
            # Get route segment 1: origin → pickup
            segment1 = OSRMRouteService.get_route(origin, pickup)
            if not segment1:
                logger.error("Failed to get route segment: origin → pickup")
                return None
            
            # Get route segment 2: pickup → destination
            segment2 = OSRMRouteService.get_route(pickup, destination)
            if not segment2:
                logger.error("Failed to get route segment: pickup → destination")
                return None
            
            # Merge polylines
            # For simplicity, we concatenate the polylines
            # In production, you might want to decode, merge coordinates, and re-encode
            merged_polyline = segment1['polyline'] + segment2['polyline']
            
            # Calculate total distance and duration
            total_distance = segment1['distance'] + segment2['distance']
            total_duration = segment1['duration'] + segment2['duration']
            
            logger.info(f"Route recalculated successfully: {total_distance}m, {total_duration}s")
            
            return {
                'polyline': merged_polyline,
                'distance': total_distance,
                'duration': total_duration,
                'segment1': segment1,
                'segment2': segment2
            }
            
        except Exception as e:
            logger.error(f"Error recalculating route with pickup: {e}")
            return None
    
    @staticmethod
    def get_multi_point_route(waypoints: List[Tuple[float, float]]) -> Optional[Dict]:
        """
        Get route through multiple waypoints using OSRM.
        
        This is an alternative approach that uses OSRM's multi-point routing.
        
        Args:
            waypoints: List of (lat, lng) tuples for waypoints
            
        Returns:
            Dictionary with route details, or None if failed
        """
        try:
            if len(waypoints) < 2:
                logger.error("Need at least 2 waypoints for routing")
                return None
            
            # Convert waypoints to OSRM format (lng,lat)
            coordinates = ';'.join([f"{lng},{lat}" for lat, lng in waypoints])
            
            # Build OSRM route URL
            url = f"{OSRMRouteService.OSRM_SERVER}/route/v1/driving/{coordinates}"
            params = {
                'overview': 'full',
                'geometries': 'polyline'
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get('code') == 'Ok' and data.get('routes'):
                route = data['routes'][0]
                return {
                    'polyline': route['geometry'],
                    'distance': route['distance'],
                    'duration': route['duration']
                }
            else:
                logger.error(f"OSRM returned error: {data.get('code')}")
                return None
                
        except Exception as e:
            logger.error(f"Error getting multi-point route: {e}")
            return None
