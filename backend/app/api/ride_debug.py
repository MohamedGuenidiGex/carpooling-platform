"""Debug endpoints for ride expiration testing."""

from flask_restx import Namespace, Resource
from flask_jwt_extended import jwt_required
from app.services.ride_expiration_service import check_and_expire_rides
import logging

api = Namespace('ride-debug', description='Debug operations for ride expiration')
logger = logging.getLogger(__name__)


@api.route('/check-expiration')
class RideExpirationDebug(Resource):
    @jwt_required()
    @api.doc(
        description='Manually trigger ride expiration check (for testing)',
        responses={
            200: 'Expiration check completed',
            401: 'Unauthorized - JWT required'
        }
    )
    def post(self):
        """Manually trigger ride expiration check"""
        try:
            expired_count, reminded_count = check_and_expire_rides()
            logger.info(f'Manual expiration check: {expired_count} expired, {reminded_count} reminded')
            
            return {
                'message': 'Expiration check completed',
                'expired_count': expired_count,
                'reminded_count': reminded_count
            }, 200
        except Exception as e:
            logger.error(f'Manual expiration check failed: {e}')
            return {
                'error': 'INTERNAL_ERROR',
                'message': f'Expiration check failed: {str(e)}'
            }, 500
