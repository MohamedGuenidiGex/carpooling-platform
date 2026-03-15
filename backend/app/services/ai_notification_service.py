"""
AI Notification Service

Handles notifications for AI-detected ride matches.
Sends notifications to passengers when matches are found.
"""

from typing import Dict, Optional
from app.models import Notification
from app.models.ai_match import AIMatch
from app.models.passenger_request import PassengerRequest
from app import db
import logging

logger = logging.getLogger(__name__)


class AINotificationService:
    """
    Service for sending notifications related to AI ride matching.
    """
    
    # Notification type constants
    NOTIFICATION_TYPE_SMART_MATCH = 'SMART_RIDE_MATCH_FOUND'
    NOTIFICATION_TYPE_PICKUP_REQUEST = 'SMART_PICKUP_REQUEST'
    NOTIFICATION_TYPE_PICKUP_CONFIRMED = 'SMART_PICKUP_CONFIRMED'
    
    @staticmethod
    def notify_passenger_match(ai_match: AIMatch) -> Optional[Notification]:
        """
        Send notification to passenger when a new AI match is created.
        
        Workflow:
        1. Retrieve passenger request to get user_id
        2. Build notification payload with match details
        3. Create notification record in database
        
        Args:
            ai_match: The AIMatch object that was just created
            
        Returns:
            Notification object if successful, None otherwise
        """
        try:
            # Get passenger request to find the user
            passenger_request = PassengerRequest.query.get(ai_match.passenger_request_id)
            if not passenger_request:
                logger.error(f"Passenger request {ai_match.passenger_request_id} not found for match {ai_match.id}")
                return None
            
            # Build notification message
            pickup_name = ai_match.pickup_name or f"({ai_match.pickup_lat:.4f}, {ai_match.pickup_lng:.4f})"
            detour_text = f"{ai_match.estimated_detour_minutes:.0f} min" if ai_match.estimated_detour_minutes < 60 else f"{ai_match.estimated_detour_minutes/60:.1f} hr"
            
            message = (
                f"Smart match found! A ride passes near {pickup_name}. "
                f"Detour: {detour_text}, Match score: {ai_match.match_score*100:.0f}%"
            )
            
            # Build notification payload
            notification_data = {
                'type': AINotificationService.NOTIFICATION_TYPE_SMART_MATCH,
                'ai_match_id': ai_match.id,
                'ride_id': ai_match.ride_id,
                'pickup_location': {
                    'lat': ai_match.pickup_lat,
                    'lng': ai_match.pickup_lng,
                    'name': ai_match.pickup_name
                },
                'detour_minutes': ai_match.estimated_detour_minutes,
                'match_score': ai_match.match_score
            }
            
            # Create notification
            notification = Notification(
                employee_id=passenger_request.user_id,
                ride_id=ai_match.ride_id,
                message=message,
                type=AINotificationService.NOTIFICATION_TYPE_SMART_MATCH
            )
            
            db.session.add(notification)
            db.session.commit()
            
            logger.info(f"Notification sent to user {passenger_request.user_id} for match {ai_match.id}")
            
            return notification
            
        except Exception as e:
            logger.error(f"Failed to send notification for match {ai_match.id}: {e}")
            db.session.rollback()
            return None
    
    @staticmethod
    def notify_match_requested(ai_match: AIMatch) -> Optional[Notification]:
        """
        Notify driver when a passenger requests an AI match.
        
        Sends SMART_PICKUP_REQUEST notification to the driver asking
        whether they accept the dynamic pickup.
        
        Args:
            ai_match: The AIMatch that was requested
            
        Returns:
            Notification object if successful, None otherwise
        """
        try:
            # Get the ride to find the driver
            from app.models import Ride
            ride = Ride.query.get(ai_match.ride_id)
            if not ride:
                logger.error(f"Ride {ai_match.ride_id} not found for match {ai_match.id}")
                return None
            
            # Get passenger request for additional context
            passenger_request = PassengerRequest.query.get(ai_match.passenger_request_id)
            if not passenger_request:
                logger.error(f"Passenger request {ai_match.passenger_request_id} not found for match {ai_match.id}")
                return None
            
            # Build notification message
            pickup_name = ai_match.pickup_name or f"({ai_match.pickup_lat:.4f}, {ai_match.pickup_lng:.4f})"
            detour_text = f"{ai_match.estimated_detour_minutes:.0f} min" if ai_match.estimated_detour_minutes < 60 else f"{ai_match.estimated_detour_minutes/60:.1f} hr"
            
            message = (
                f"Smart pickup request! A passenger wants to join your ride at {pickup_name}. "
                f"Detour: {detour_text}, Match score: {ai_match.match_score*100:.0f}%"
            )
            
            # Build notification payload
            notification_data = {
                'type': AINotificationService.NOTIFICATION_TYPE_PICKUP_REQUEST,
                'ai_match_id': ai_match.id,
                'passenger_request_id': ai_match.passenger_request_id,
                'ride_id': ai_match.ride_id,
                'pickup_location': {
                    'lat': ai_match.pickup_lat,
                    'lng': ai_match.pickup_lng,
                    'name': ai_match.pickup_name
                },
                'detour_minutes': ai_match.estimated_detour_minutes,
                'match_score': ai_match.match_score
            }
            
            # Create notification for driver
            notification = Notification(
                employee_id=ride.driver_id,
                ride_id=ai_match.ride_id,
                message=message,
                type=AINotificationService.NOTIFICATION_TYPE_PICKUP_REQUEST
            )
            
            db.session.add(notification)
            db.session.commit()
            
            logger.info(f"Pickup request notification sent to driver {ride.driver_id} for match {ai_match.id}")
            
            return notification
            
        except Exception as e:
            logger.error(f"Failed to send pickup request notification for match {ai_match.id}: {e}")
            db.session.rollback()
            return None
    
    @staticmethod
    def notify_pickup_confirmed(ai_match: AIMatch) -> Optional[Notification]:
        """
        Notify passenger when driver accepts their pickup request.
        
        Sends SMART_PICKUP_CONFIRMED notification to the passenger confirming
        that the driver has accepted and a reservation has been created.
        
        Args:
            ai_match: The AIMatch that was accepted
            
        Returns:
            Notification object if successful, None otherwise
        """
        try:
            # Get passenger request to find the user
            passenger_request = PassengerRequest.query.get(ai_match.passenger_request_id)
            if not passenger_request:
                logger.error(f"Passenger request {ai_match.passenger_request_id} not found for match {ai_match.id}")
                return None
            
            # Build notification message
            pickup_name = ai_match.pickup_name or f"({ai_match.pickup_lat:.4f}, {ai_match.pickup_lng:.4f})"
            
            message = (
                f"Great news! Your smart pickup request has been confirmed. "
                f"The driver will pick you up at {pickup_name}."
            )
            
            # Create notification for passenger
            notification = Notification(
                employee_id=passenger_request.user_id,
                ride_id=ai_match.ride_id,
                message=message,
                type=AINotificationService.NOTIFICATION_TYPE_PICKUP_CONFIRMED
            )
            
            db.session.add(notification)
            db.session.commit()
            
            logger.info(f"Pickup confirmation notification sent to passenger {passenger_request.user_id} for match {ai_match.id}")
            
            return notification
            
        except Exception as e:
            logger.error(f"Failed to send pickup confirmation notification for match {ai_match.id}: {e}")
            db.session.rollback()
            return None
    
    @staticmethod
    def get_notification_payload(ai_match: AIMatch) -> Dict:
        """
        Build notification payload for an AI match.
        
        Args:
            ai_match: The AIMatch object
            
        Returns:
            Dictionary with notification payload
        """
        return {
            'type': AINotificationService.NOTIFICATION_TYPE_SMART_MATCH,
            'ai_match_id': ai_match.id,
            'ride_id': ai_match.ride_id,
            'pickup_location': {
                'lat': ai_match.pickup_lat,
                'lng': ai_match.pickup_lng,
                'name': ai_match.pickup_name
            },
            'detour_minutes': ai_match.estimated_detour_minutes,
            'match_score': ai_match.match_score,
            'status': ai_match.status
        }
