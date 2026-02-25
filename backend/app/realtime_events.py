"""Real-time event handlers for WebSocket connections."""

from flask_socketio import emit, join_room, leave_room, disconnect
from flask import request
from flask_jwt_extended import decode_token
import logging

logger = logging.getLogger(__name__)


def register_socket_handlers(socketio):
    """Register all WebSocket event handlers."""

    @socketio.on('connect')
    def handle_connect():
        """Handle client connection."""
        try:
            # Get JWT token from query parameters or headers
            token = request.args.get('token')
            
            if not token:
                logger.warning('Connection attempt without token')
                return False  # Reject connection
            
            try:
                # Decode token to get user identity
                decoded = decode_token(token)
                user_id = int(decoded['sub'])
                logger.info(f'User {user_id} connected via WebSocket')
                emit('connection_response', {'data': 'Connected to server'})
            except Exception as e:
                logger.warning(f'Invalid token on connect: {e}')
                return False  # Reject connection
                
        except Exception as e:
            logger.error(f'Error in connect handler: {e}')
            return False

    @socketio.on('disconnect')
    def handle_disconnect():
        """Handle client disconnection."""
        try:
            logger.info(f'Client disconnected: {request.sid}')
        except Exception as e:
            logger.error(f'Error in disconnect handler: {e}')

    @socketio.on('join_ride')
    def on_join_ride(data):
        """
        Handle user joining a ride-specific room.
        
        Expected data: {'ride_id': <int>}
        Room name format: ride_<ride_id>
        """
        try:
            ride_id = data.get('ride_id')
            
            if not ride_id:
                emit('error', {'message': 'ride_id is required'})
                return
            
            room = f'ride_{ride_id}'
            join_room(room)
            logger.info(f'Client {request.sid} joined room {room}')
            emit('joined_ride', {'ride_id': ride_id, 'message': f'Joined ride {ride_id}'})
            
        except Exception as e:
            logger.error(f'Error in join_ride handler: {e}')
            emit('error', {'message': str(e)})

    @socketio.on('leave_ride')
    def on_leave_ride(data):
        """
        Handle user leaving a ride-specific room.
        
        Expected data: {'ride_id': <int>}
        """
        try:
            ride_id = data.get('ride_id')
            
            if not ride_id:
                emit('error', {'message': 'ride_id is required'})
                return
            
            room = f'ride_{ride_id}'
            leave_room(room)
            logger.info(f'Client {request.sid} left room {room}')
            emit('left_ride', {'ride_id': ride_id, 'message': f'Left ride {ride_id}'})
            
        except Exception as e:
            logger.error(f'Error in leave_ride handler: {e}')
            emit('error', {'message': str(e)})


def emit_ride_status_update(socketio, ride_id, new_status, updated_at):
    """
    Emit ride status update to all clients in the ride room.
    
    Args:
        socketio: SocketIO instance
        ride_id: ID of the ride
        new_status: New status of the ride (e.g., 'ACTIVE', 'FULL', 'COMPLETED')
        updated_at: ISO timestamp of the update
    """
    room = f'ride_{ride_id}'
    payload = {
        'ride_id': ride_id,
        'new_status': new_status,
        'updated_at': updated_at
    }
    
    try:
        socketio.emit(
            'ride_status_updated',
            payload,
            room=room
        )
        logger.info(f'Emitted ride_status_updated to room {room}: {payload}')
    except Exception as e:
        logger.error(f'Error emitting ride_status_updated: {e}')
