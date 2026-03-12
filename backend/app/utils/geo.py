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
    
    Supports three search scenarios:
    1. Origin-only: Only search_origin_lat/lng provided
    2. Destination-only: Only search_dest_lat/lng provided
    3. Both: Both origin and destination provided
    
    Args:
        search_origin_lat, search_origin_lng: Passenger's pickup location (can be None)
        search_dest_lat, search_dest_lng: Passenger's destination (can be None)
        ride_origin_lat, ride_origin_lng: Ride's origin coordinates
        ride_dest_lat, ride_dest_lng: Ride's destination coordinates
        pickup_radius_km: Maximum distance for origin match (default: PICKUP_RADIUS_KM)
        destination_radius_km: Maximum distance for destination match (default: DESTINATION_RADIUS_KM)
        
    Returns:
        True if the ride matches the search criteria
    """
    # Determine which coordinates are provided
    has_search_origin = search_origin_lat is not None and search_origin_lng is not None
    has_search_dest = search_dest_lat is not None and search_dest_lng is not None
    
    # If no search coordinates provided, don't match (invalid search)
    if not has_search_origin and not has_search_dest:
        return False
    
    # Check if ride has required coordinates
    has_ride_origin = ride_origin_lat is not None and ride_origin_lng is not None
    has_ride_dest = ride_dest_lat is not None and ride_dest_lng is not None
    
    # Scenario 1: Origin-only search
    if has_search_origin and not has_search_dest:
        if not has_ride_origin:
            return False
        return is_within_radius(
            search_origin_lat, search_origin_lng,
            ride_origin_lat, ride_origin_lng,
            pickup_radius_km
        )
    
    # Scenario 2: Destination-only search
    if has_search_dest and not has_search_origin:
        if not has_ride_dest:
            return False
        return is_within_radius(
            search_dest_lat, search_dest_lng,
            ride_dest_lat, ride_dest_lng,
            destination_radius_km
        )
    
    # Scenario 3: Both origin and destination search
    if has_search_origin and has_search_dest:
        if not has_ride_origin or not has_ride_dest:
            return False
        
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
    
    return False
