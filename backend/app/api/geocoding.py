"""Geocoding API - Proxy for OpenStreetMap Nominatim service."""

from flask import request
from flask_restx import Namespace, Resource, fields
import requests
import logging

logger = logging.getLogger(__name__)

api = Namespace('geocoding', description='Geocoding and place search operations')

# Response models
place_model = api.model('Place', {
    'display_name': fields.String(description='Full display name of the place'),
    'lat': fields.Float(description='Latitude coordinate'),
    'lon': fields.Float(description='Longitude coordinate'),
    'place_id': fields.Integer(description='OpenStreetMap place ID'),
    'osm_type': fields.String(description='OpenStreetMap object type'),
})

search_response = api.model('SearchResponse', {
    'results': fields.List(fields.Nested(place_model), description='List of matching places'),
})

address_response = api.model('AddressResponse', {
    'address': fields.String(description='Formatted address string'),
})

error_response = api.model('ErrorResponse', {
    'error': fields.String(description='Error message'),
})


@api.route('/search')
class GeocodingSearch(Resource):
    @api.doc(
        'search_places',
        description='Search for places by query string using OpenStreetMap Nominatim',
        responses={
            200: ('Places found', search_response),
            400: ('Validation error', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.param('q', 'Search query (e.g., "Sousse, Tunisia")', required=True)
    @api.param('limit', 'Maximum number of results (default: 5)', required=False)
    def get(self):
        """Search for places by query string"""
        query = api.payload.get('q') if api.payload else None
        if not query:
            query = request.args.get('q')
        
        if not query:
            api.abort(400, 'Query parameter "q" is required')
        
        limit = request.args.get('limit', 5, type=int)
        
        try:
            # Call Nominatim API
            nominatim_url = 'https://nominatim.openstreetmap.org/search'
            params = {
                'q': query,
                'format': 'json',
                'limit': limit,
                'countrycodes': 'tn',  # Tunisia only
            }
            headers = {
                'User-Agent': 'com.gexpertise.carpooling',
            }
            
            response = requests.get(nominatim_url, params=params, headers=headers, timeout=10)
            
            if response.status_code == 200:
                results = response.json()
                # Filter and format results
                formatted_results = []
                for item in results:
                    formatted_results.append({
                        'display_name': item.get('display_name', 'Unknown location'),
                        'lat': float(item.get('lat', 0)),
                        'lon': float(item.get('lon', 0)),
                        'place_id': item.get('place_id'),
                        'osm_type': item.get('osm_type'),
                    })
                
                return {'results': formatted_results}, 200
            else:
                logger.error(f'Nominatim API error: {response.status_code}')
                api.abort(500, f'Nominatim API error: {response.status_code}')
                
        except requests.Timeout:
            logger.error('Nominatim API timeout')
            api.abort(500, 'Nominatim API timeout')
        except Exception as e:
            logger.error(f'Geocoding search error: {e}')
            api.abort(500, f'Geocoding search error: {str(e)}')


@api.route('/reverse')
class GeocodingReverse(Resource):
    @api.doc(
        'reverse_geocode',
        description='Get address from coordinates using OpenStreetMap Nominatim',
        responses={
            200: ('Address found', address_response),
            400: ('Validation error', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.param('lat', 'Latitude coordinate', required=True)
    @api.param('lon', 'Longitude coordinate', required=True)
    def get(self):
        """Reverse geocode - get address from coordinates"""
        try:
            lat = request.args.get('lat', type=float)
            lon = request.args.get('lon', type=float)
            
            if lat is None or lon is None:
                api.abort(400, 'Both "lat" and "lon" parameters are required')
            
            # Call Nominatim API
            nominatim_url = 'https://nominatim.openstreetmap.org/reverse'
            params = {
                'lat': lat,
                'lon': lon,
                'format': 'json',
                'addressdetails': 1,
            }
            headers = {
                'User-Agent': 'com.gexpertise.carpooling',
            }
            
            response = requests.get(nominatim_url, params=params, headers=headers, timeout=10)
            
            if response.status_code == 200:
                result = response.json()
                
                # Build clean address from components
                address_data = result.get('address', {})
                parts = []
                
                # Road/street
                if address_data.get('road'):
                    parts.append(address_data['road'])
                elif address_data.get('street'):
                    parts.append(address_data['street'])
                
                # Suburb/neighborhood
                if address_data.get('suburb'):
                    parts.append(address_data['suburb'])
                elif address_data.get('neighbourhood'):
                    parts.append(address_data['neighbourhood'])
                
                # City/town
                if address_data.get('city'):
                    parts.append(address_data['city'])
                elif address_data.get('town'):
                    parts.append(address_data['town'])
                elif address_data.get('village'):
                    parts.append(address_data['village'])
                
                # State/country
                if address_data.get('state'):
                    parts.append(address_data['state'])
                if address_data.get('country'):
                    parts.append(address_data['country'])
                
                # Return clean address (first 3 parts)
                if parts:
                    address = ', '.join(parts[:3])
                else:
                    # Fallback to display_name
                    display_name = result.get('display_name', '')
                    if display_name:
                        parts = display_name.split(', ')
                        address = ', '.join(parts[:3]) if len(parts) > 3 else display_name
                    else:
                        address = f'{lat:.4f}, {lon:.4f}'
                
                return {'address': address}, 200
            else:
                logger.error(f'Nominatim API error: {response.status_code}')
                api.abort(500, f'Nominatim API error: {response.status_code}')
                
        except requests.Timeout:
            logger.error('Nominatim API timeout')
            api.abort(500, 'Nominatim API timeout')
        except Exception as e:
            logger.error(f'Reverse geocoding error: {e}')
            api.abort(500, f'Reverse geocoding error: {str(e)}')
