"""
Geocoding Service

Provides reverse geocoding using Nominatim (OpenStreetMap).
Converts coordinates to human-readable location names.
"""

import requests
import logging
from typing import Optional, Tuple
import time

logger = logging.getLogger(__name__)


class GeocodingService:
    """
    Service for reverse geocoding using Nominatim API.
    """
    
    # Nominatim server URL
    NOMINATIM_SERVER = "https://nominatim.openstreetmap.org"
    
    # User agent (required by Nominatim usage policy)
    USER_AGENT = "GExpertise-Carpool/1.0"
    
    # Rate limiting (Nominatim requires max 1 request per second)
    _last_request_time = 0
    _min_request_interval = 1.0  # seconds
    
    @staticmethod
    def reverse_geocode(lat: float, lng: float) -> Optional[str]:
        """
        Convert coordinates to human-readable location name.
        
        Uses Nominatim reverse geocoding API to get address information.
        
        Args:
            lat: Latitude
            lng: Longitude
            
        Returns:
            Human-readable location name, or None if failed
        """
        try:
            # Rate limiting (respect Nominatim usage policy)
            current_time = time.time()
            time_since_last = current_time - GeocodingService._last_request_time
            if time_since_last < GeocodingService._min_request_interval:
                time.sleep(GeocodingService._min_request_interval - time_since_last)
            
            # Build Nominatim reverse geocoding URL
            url = f"{GeocodingService.NOMINATIM_SERVER}/reverse"
            params = {
                'lat': lat,
                'lon': lng,
                'format': 'json',
                'addressdetails': 1,
                'zoom': 18  # Street level detail
            }
            headers = {
                'User-Agent': GeocodingService.USER_AGENT
            }
            
            response = requests.get(url, params=params, headers=headers, timeout=10)
            GeocodingService._last_request_time = time.time()
            
            response.raise_for_status()
            
            data = response.json()
            
            if 'error' in data:
                logger.error(f"Nominatim returned error: {data.get('error')}")
                return None
            
            # Extract location name from response
            location_name = GeocodingService._extract_location_name(data)
            
            logger.info(f"Reverse geocoded ({lat}, {lng}) → {location_name}")
            
            return location_name
            
        except requests.RequestException as e:
            logger.error(f"Nominatim API request failed: {e}")
            return None
        except Exception as e:
            logger.error(f"Error in reverse geocoding: {e}")
            return None
    
    @staticmethod
    def _extract_location_name(data: dict) -> str:
        """
        Extract the most relevant location name from Nominatim response.
        
        Prioritizes: road > suburb > city > display_name
        
        Args:
            data: Nominatim response data
            
        Returns:
            Human-readable location name
        """
        address = data.get('address', {})
        
        # Try to get the most specific location name
        # Priority: road/street > suburb/neighbourhood > city > display_name
        
        if 'road' in address:
            road = address['road']
            # Add suburb or city for context if available
            if 'suburb' in address:
                return f"{road}, {address['suburb']}"
            elif 'city' in address:
                return f"{road}, {address['city']}"
            return road
        
        if 'suburb' in address or 'neighbourhood' in address:
            location = address.get('suburb') or address.get('neighbourhood')
            if 'city' in address:
                return f"{location}, {address['city']}"
            return location
        
        if 'city' in address or 'town' in address or 'village' in address:
            return address.get('city') or address.get('town') or address.get('village')
        
        # Fallback to display_name (full address)
        display_name = data.get('display_name', '')
        # Truncate if too long
        if len(display_name) > 100:
            parts = display_name.split(',')
            return ', '.join(parts[:3])  # First 3 parts
        
        return display_name or f"Location ({data.get('lat')}, {data.get('lon')})"
    
    @staticmethod
    def get_location_name_with_fallback(lat: float, lng: float) -> str:
        """
        Get location name with fallback to coordinates if geocoding fails.
        
        Args:
            lat: Latitude
            lng: Longitude
            
        Returns:
            Human-readable location name or formatted coordinates
        """
        location_name = GeocodingService.reverse_geocode(lat, lng)
        
        if location_name:
            return location_name
        
        # Fallback to formatted coordinates
        return f"Near {lat:.4f}, {lng:.4f}"
