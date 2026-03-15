"""
AI Matches API

Endpoints for passengers to view and interact with AI-detected ride matches.
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity
import logging

from app.repositories.ai_match_repository import AIMatchRepository
from app.services.ai_notification_service import AINotificationService
from app.models.ai_match import AIMatch
from app.models.passenger_request import PassengerRequest

logger = logging.getLogger(__name__)

api = Namespace('ai', description='AI ride matching operations')

# Error response model
error_response = api.model('ErrorResponse', {
    'error': fields.String(description='Error code'),
    'message': fields.String(description='Error message')
})

# AI Match response model
ai_match_response = api.model('AIMatchResponse', {
    'match_id': fields.Integer(description='AI match ID'),
    'ride_id': fields.Integer(description='Ride ID'),
    'pickup_location': fields.Raw(description='Pickup location details'),
    'detour_minutes': fields.Float(description='Estimated detour time in minutes'),
    'match_score': fields.Float(description='Match quality score (0-1)'),
    'status': fields.String(description='Match status'),
    'distance_to_route': fields.Float(description='Distance to route in km'),
    'created_at': fields.String(description='Match creation timestamp')
})


@api.route('/matches')
class AIMatchList(Resource):
    @jwt_required()
    @api.doc('get_ai_matches', security='Bearer',
        responses={
            200: ('Success', [ai_match_response]),
            401: ('Unauthorized - JWT required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def get(self):
        """
        Get all suggested AI matches for the current authenticated passenger.
        
        Returns matches where:
        - Passenger has an open request
        - Match status is 'suggested'
        - Ordered by match score (highest first)
        """
        try:
            current_user_id = get_jwt_identity()
            
            # Get all passenger requests for this user
            passenger_requests = PassengerRequest.query.filter_by(
                user_id=current_user_id,
                status='open'
            ).all()
            
            if not passenger_requests:
                return [], 200
            
            # Collect all matches for these requests
            all_matches = []
            for request in passenger_requests:
                matches = AIMatchRepository.get_matches_for_passenger(
                    request.id,
                    status=AIMatch.STATUS_SUGGESTED
                )
                
                for match in matches:
                    all_matches.append({
                        'match_id': match.id,
                        'ride_id': match.ride_id,
                        'pickup_location': {
                            'lat': match.pickup_lat,
                            'lng': match.pickup_lng,
                            'name': match.pickup_name
                        },
                        'detour_minutes': match.estimated_detour_minutes,
                        'match_score': match.match_score,
                        'status': match.status,
                        'distance_to_route': match.distance_to_route,
                        'created_at': match.created_at.isoformat() if match.created_at else None
                    })
            
            # Sort by match score (highest first)
            all_matches.sort(key=lambda x: x['match_score'], reverse=True)
            
            logger.info(f"User {current_user_id} retrieved {len(all_matches)} AI matches")
            
            return all_matches, 200
            
        except Exception as e:
            logger.error(f"Error retrieving AI matches: {e}")
            return {
                'error': 'INTERNAL_ERROR',
                'message': 'Failed to retrieve AI matches'
            }, 500


@api.route('/matches/<int:match_id>')
class AIMatchDetail(Resource):
    @jwt_required()
    @api.doc('get_ai_match_by_id', security='Bearer',
        params={'match_id': 'AI match ID'},
        responses={
            200: ('Success', ai_match_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - not your match', error_response),
            404: ('Match not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def get(self, match_id):
        """
        Get a specific AI match by ID.
        
        Used when opening match details from a notification.
        Verifies the match belongs to the current user (passenger or driver).
        """
        try:
            current_user_id = get_jwt_identity()
            
            # Get the match
            match = AIMatchRepository.get_match_by_id(match_id)
            if not match:
                return {
                    'error': 'NOT_FOUND',
                    'message': 'AI match not found'
                }, 404
            
            # Verify this match belongs to the current user
            # User can be either the passenger or the driver
            passenger_request = PassengerRequest.query.get(match.passenger_request_id)
            
            from app.models import Ride
            ride = Ride.query.get(match.ride_id)
            
            is_passenger = passenger_request and passenger_request.user_id == current_user_id
            is_driver = ride and ride.driver_id == current_user_id
            
            if not (is_passenger or is_driver):
                return {
                    'error': 'FORBIDDEN',
                    'message': 'This match does not belong to you'
                }, 403
            
            # Return match details
            return {
                'match_id': match.id,
                'ride_id': match.ride_id,
                'pickup_location': {
                    'lat': match.pickup_lat,
                    'lng': match.pickup_lng,
                    'name': match.pickup_name
                },
                'detour_minutes': match.estimated_detour_minutes,
                'match_score': match.match_score,
                'status': match.status,
                'distance_to_route': match.distance_to_route,
                'created_at': match.created_at.isoformat() if match.created_at else None
            }, 200
            
        except Exception as e:
            logger.error(f"Error retrieving AI match {match_id}: {e}")
            return {
                'error': 'INTERNAL_ERROR',
                'message': 'Failed to retrieve AI match'
            }, 500


@api.route('/matches/<int:match_id>/request')
class AIMatchRequest(Resource):
    @jwt_required()
    @api.doc('request_ai_match', security='Bearer',
        params={'match_id': 'AI match ID'},
        responses={
            200: ('Match requested successfully', ai_match_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - not your match', error_response),
            404: ('Match not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def post(self, match_id):
        """
        Request an AI match (passenger indicates interest).
        
        Updates match status from 'suggested' to 'requested'.
        """
        try:
            current_user_id = get_jwt_identity()
            
            # Get the match
            match = AIMatchRepository.get_match_by_id(match_id)
            if not match:
                return {
                    'error': 'NOT_FOUND',
                    'message': 'AI match not found'
                }, 404
            
            # Verify this match belongs to the current user
            passenger_request = PassengerRequest.query.get(match.passenger_request_id)
            if not passenger_request or passenger_request.user_id != current_user_id:
                return {
                    'error': 'FORBIDDEN',
                    'message': 'This match does not belong to you'
                }, 403
            
            # Update status to 'requested'
            updated_match = AIMatchRepository.update_match_status(
                match_id,
                AIMatch.STATUS_REQUESTED
            )
            
            if not updated_match:
                return {
                    'error': 'INTERNAL_ERROR',
                    'message': 'Failed to update match status'
                }, 500
            
            # Send notification to driver
            try:
                AINotificationService.notify_match_requested(updated_match)
            except Exception as notif_error:
                logger.error(f"Failed to send driver notification for match {match_id}: {notif_error}")
            
            logger.info(f"User {current_user_id} requested match {match_id}")
            
            return {
                'match_id': updated_match.id,
                'ride_id': updated_match.ride_id,
                'pickup_location': {
                    'lat': updated_match.pickup_lat,
                    'lng': updated_match.pickup_lng,
                    'name': updated_match.pickup_name
                },
                'detour_minutes': updated_match.estimated_detour_minutes,
                'match_score': updated_match.match_score,
                'status': updated_match.status,
                'distance_to_route': updated_match.distance_to_route,
                'created_at': updated_match.created_at.isoformat() if updated_match.created_at else None
            }, 200
            
        except Exception as e:
            logger.error(f"Error requesting AI match {match_id}: {e}")
            return {
                'error': 'INTERNAL_ERROR',
                'message': 'Failed to request match'
            }, 500


@api.route('/matches/<int:match_id>/reject')
class AIMatchReject(Resource):
    @jwt_required()
    @api.doc('reject_ai_match', security='Bearer',
        params={'match_id': 'AI match ID'},
        responses={
            200: ('Match rejected successfully', ai_match_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - not your match', error_response),
            404: ('Match not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def post(self, match_id):
        """
        Reject an AI match (passenger not interested).
        
        Updates match status from 'suggested' to 'rejected'.
        """
        try:
            current_user_id = get_jwt_identity()
            
            # Get the match
            match = AIMatchRepository.get_match_by_id(match_id)
            if not match:
                return {
                    'error': 'NOT_FOUND',
                    'message': 'AI match not found'
                }, 404
            
            # Verify this match belongs to the current user
            passenger_request = PassengerRequest.query.get(match.passenger_request_id)
            if not passenger_request or passenger_request.user_id != current_user_id:
                return {
                    'error': 'FORBIDDEN',
                    'message': 'This match does not belong to you'
                }, 403
            
            # Update status to 'rejected'
            updated_match = AIMatchRepository.update_match_status(
                match_id,
                AIMatch.STATUS_REJECTED
            )
            
            if not updated_match:
                return {
                    'error': 'INTERNAL_ERROR',
                    'message': 'Failed to update match status'
                }, 500
            
            logger.info(f"User {current_user_id} rejected match {match_id}")
            
            return {
                'match_id': updated_match.id,
                'ride_id': updated_match.ride_id,
                'pickup_location': {
                    'lat': updated_match.pickup_lat,
                    'lng': updated_match.pickup_lng,
                    'name': updated_match.pickup_name
                },
                'detour_minutes': updated_match.estimated_detour_minutes,
                'match_score': updated_match.match_score,
                'status': updated_match.status,
                'distance_to_route': updated_match.distance_to_route,
                'created_at': updated_match.created_at.isoformat() if updated_match.created_at else None
            }, 200
            
        except Exception as e:
            logger.error(f"Error rejecting AI match {match_id}: {e}")
            return {
                'error': 'INTERNAL_ERROR',
                'message': 'Failed to reject match'
            }, 500


@api.route('/matches/<int:match_id>/accept')
class AIMatchAccept(Resource):
    @jwt_required()
    @api.doc('accept_ai_match', security='Bearer',
        params={'match_id': 'AI match ID'},
        responses={
            200: ('Match accepted successfully', ai_match_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - not the ride driver', error_response),
            404: ('Match not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def post(self, match_id):
        """
        Accept a pickup request (driver accepts dynamic pickup).
        
        Updates match status to 'accepted', stores dynamic pickup in ride,
        creates reservation for passenger, and sends confirmation notification.
        Only the ride driver can accept the request.
        """
        try:
            from app.models import Ride, Reservation
            from app import db
            
            current_user_id = get_jwt_identity()
            
            # Get the match
            match = AIMatchRepository.get_match_by_id(match_id)
            if not match:
                return {
                    'error': 'NOT_FOUND',
                    'message': 'AI match not found'
                }, 404
            
            # Get the ride to verify driver
            ride = Ride.query.get(match.ride_id)
            if not ride:
                return {
                    'error': 'NOT_FOUND',
                    'message': 'Ride not found'
                }, 404
            
            # Security check: only the ride driver can accept
            if ride.driver_id != current_user_id:
                return {
                    'error': 'FORBIDDEN',
                    'message': 'Only the ride driver can accept this request'
                }, 403
            
            # Get passenger request to get passenger user_id
            passenger_request = PassengerRequest.query.get(match.passenger_request_id)
            if not passenger_request:
                return {
                    'error': 'NOT_FOUND',
                    'message': 'Passenger request not found'
                }, 404
            
            # Check if passenger already has a reservation for this ride
            existing_reservation = Reservation.query.filter_by(
                ride_id=ride.id,
                employee_id=passenger_request.user_id
            ).first()
            
            if existing_reservation:
                logger.warning(f"Passenger {passenger_request.user_id} already has reservation for ride {ride.id}")
            else:
                # Create reservation for passenger
                reservation = Reservation(
                    employee_id=passenger_request.user_id,
                    ride_id=ride.id,
                    seats_reserved=1,
                    status='confirmed'
                )
                db.session.add(reservation)
                
                # Update ride available seats
                if ride.available_seats > 0:
                    ride.available_seats -= 1
                
                logger.info(f"Created reservation for passenger {passenger_request.user_id} on ride {ride.id}")
            
            # Update match status to 'accepted'
            updated_match = AIMatchRepository.update_match_status(
                match_id,
                AIMatch.STATUS_ACCEPTED
            )
            
            if not updated_match:
                db.session.rollback()
                return {
                    'error': 'INTERNAL_ERROR',
                    'message': 'Failed to update match status'
                }, 500
            
            # Store dynamic pickup in ride
            ride.dynamic_pickup_lat = updated_match.pickup_lat
            ride.dynamic_pickup_lng = updated_match.pickup_lng
            ride.dynamic_pickup_name = updated_match.pickup_name
            
            # Recalculate OSRM route with dynamic pickup
            try:
                from app.services.osrm_route_service import OSRMRouteService
                
                if ride.origin_lat and ride.origin_lng and ride.destination_lat and ride.destination_lng:
                    new_route = OSRMRouteService.recalculate_route_with_pickup(
                        origin=(ride.origin_lat, ride.origin_lng),
                        pickup=(ride.dynamic_pickup_lat, ride.dynamic_pickup_lng),
                        destination=(ride.destination_lat, ride.destination_lng)
                    )
                    
                    if new_route:
                        ride.route_polyline = new_route['polyline']
                        logger.info(f"Route recalculated for ride {ride.id}: {new_route['distance']}m, {new_route['duration']}s")
                    else:
                        logger.warning(f"Failed to recalculate route for ride {ride.id}, keeping original route")
            except Exception as route_error:
                logger.error(f"Error recalculating route for ride {ride.id}: {route_error}")
            
            db.session.commit()
            
            # Send confirmation notification to passenger
            try:
                AINotificationService.notify_pickup_confirmed(updated_match)
            except Exception as notif_error:
                logger.error(f"Failed to send confirmation notification for match {match_id}: {notif_error}")
            
            logger.info(f"Driver {current_user_id} accepted match {match_id}, reservation created, dynamic pickup stored in ride {ride.id}")
            
            return {
                'match_id': updated_match.id,
                'ride_id': updated_match.ride_id,
                'pickup_location': {
                    'lat': updated_match.pickup_lat,
                    'lng': updated_match.pickup_lng,
                    'name': updated_match.pickup_name
                },
                'detour_minutes': updated_match.estimated_detour_minutes,
                'match_score': updated_match.match_score,
                'status': updated_match.status,
                'distance_to_route': updated_match.distance_to_route,
                'created_at': updated_match.created_at.isoformat() if updated_match.created_at else None,
                'reservation_created': not existing_reservation
            }, 200
            
        except Exception as e:
            logger.error(f"Error accepting AI match {match_id}: {e}")
            import traceback
            traceback.print_exc()
            db.session.rollback()
            return {
                'error': 'INTERNAL_ERROR',
                'message': 'Failed to accept match'
            }, 500


@api.route('/matches/<int:match_id>/decline')
class AIMatchDecline(Resource):
    @jwt_required()
    @api.doc('decline_ai_match', security='Bearer',
        params={'match_id': 'AI match ID'},
        responses={
            200: ('Match declined successfully', ai_match_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - not the ride driver', error_response),
            404: ('Match not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def post(self, match_id):
        """
        Decline a pickup request (driver rejects dynamic pickup).
        
        Updates match status to 'rejected'. No ride modification occurs.
        Only the ride driver can decline the request.
        """
        try:
            from app.models import Ride
            
            current_user_id = get_jwt_identity()
            
            # Get the match
            match = AIMatchRepository.get_match_by_id(match_id)
            if not match:
                return {
                    'error': 'NOT_FOUND',
                    'message': 'AI match not found'
                }, 404
            
            # Get the ride to verify driver
            ride = Ride.query.get(match.ride_id)
            if not ride:
                return {
                    'error': 'NOT_FOUND',
                    'message': 'Ride not found'
                }, 404
            
            # Security check: only the ride driver can decline
            if ride.driver_id != current_user_id:
                return {
                    'error': 'FORBIDDEN',
                    'message': 'Only the ride driver can decline this request'
                }, 403
            
            # Update match status to 'rejected'
            updated_match = AIMatchRepository.update_match_status(
                match_id,
                AIMatch.STATUS_REJECTED
            )
            
            if not updated_match:
                return {
                    'error': 'INTERNAL_ERROR',
                    'message': 'Failed to update match status'
                }, 500
            
            logger.info(f"Driver {current_user_id} declined match {match_id}")
            
            return {
                'match_id': updated_match.id,
                'ride_id': updated_match.ride_id,
                'pickup_location': {
                    'lat': updated_match.pickup_lat,
                    'lng': updated_match.pickup_lng,
                    'name': updated_match.pickup_name
                },
                'detour_minutes': updated_match.estimated_detour_minutes,
                'match_score': updated_match.match_score,
                'status': updated_match.status,
                'distance_to_route': updated_match.distance_to_route,
                'created_at': updated_match.created_at.isoformat() if updated_match.created_at else None
            }, 200
            
        except Exception as e:
            logger.error(f"Error declining AI match {match_id}: {e}")
            return {
                'error': 'INTERNAL_ERROR',
                'message': 'Failed to decline match'
            }, 500
