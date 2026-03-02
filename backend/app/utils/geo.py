"""Geo-distance utilities for coordinate-based ride matching."""

import math

# Configurable radius constants (in kilometers)
PICKUP_RADIUS_KM = 3.0
DESTINATION_RADIUS_KM = 5.0


def haversine_distance(lat1, lon1, lat2, lon2):
    """
    Calculate the great-circle distance between two points on Earth.
    Uses the Haversine formula for accuracy.
    
    Args:
        lat1, lon1: Coordinates of first point (in decimal degrees)
        lat2, lon2: Coordinates of second point (in decimal degrees)
        
    Returns:
        Distance in kilometers (float)
        
    Formula:
        a = sin²(Δφ/2) + cos φ1 ⋅ cos φ2 ⋅ sin²(Δλ/2)
        c = 2 ⋅ atan2(√a, √(1−a))
        d = R ⋅ c
        
    where φ is latitude, λ is longitude, R is earth's radius (6371 km)
    """
    # Earth's radius in kilometers
    R = 6371.0
    
    # Convert decimal degrees to radians
    lat1_rad = math.radians(lat1)
    lon1_rad = math.radians(lon1)
    lat2_rad = math.radians(lat2)
    lon2_rad = math.radians(lon2)
    
    # Differences
    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad
    
    # Haversine formula
    a = math.sin(dlat / 2)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    
    distance = R * c
    
    return distance


def is_within_radius(point1_lat, point1_lon, point2_lat, point2_lon, radius_km):
    """
    Check if two points are within a specified radius.
    
    Args:
        point1_lat, point1_lon: Coordinates of first point
        point2_lat, point2_lon: Coordinates of second point
        radius_km: Maximum distance in kilometers
        
    Returns:
        True if points are within radius, False otherwise
    """
    distance = haversine_distance(point1_lat, point1_lon, point2_lat, point2_lon)
    return distance <= radius_km


def matches_ride_location(search_origin_lat, search_origin_lng, 
                          search_dest_lat, search_dest_lng,
                          ride_origin_lat, ride_origin_lng,
                          ride_dest_lat, ride_dest_lng,
                          pickup_radius_km=PICKUP_RADIUS_KM,
                          destination_radius_km=DESTINATION_RADIUS_KM):
    """
    Check if a ride matches search coordinates within configured radii.
    
    This is the primary function for coordinate-based ride matching.
    
    Args:
        search_origin_lat, search_origin_lng: Passenger's pickup location
        search_dest_lat, search_dest_lng: Passenger's destination
        ride_origin_lat, ride_origin_lng: Ride's origin coordinates
        ride_dest_lat, ride_dest_lng: Ride's destination coordinates
        pickup_radius_km: Maximum distance for origin match (default: PICKUP_RADIUS_KM)
        destination_radius_km: Maximum distance for destination match (default: DESTINATION_RADIUS_KM)
        
    Returns:
        True if both origin and destination are within their respective radii
    """
    # Check if any coordinates are missing
    if None in [search_origin_lat, search_origin_lng, search_dest_lat, search_dest_lng,
                ride_origin_lat, ride_origin_lng, ride_dest_lat, ride_dest_lng]:
        return False
    
    # Both origin and destination must be within their respective radii
    origin_match = is_within_radius(
        search_origin_lat, search_origin_lng,
        ride_origin_lat, ride_origin_lng,
        pickup_radius_km
    )
    
    destination_match = is_within_radius(
        search_dest_lat, search_dest_lng,
        ride_dest_lat, ride_dest_lng,
        destination_radius_km
    )
    
    return origin_match and destination_match
