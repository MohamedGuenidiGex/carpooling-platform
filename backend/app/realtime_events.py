"""Real-time event handlers for WebSocket connections."""

from flask_socketio import emit, join_room, leave_room, disconnect
from flask import request
from flask_jwt_extended import decode_token
import logging

logger = logging.getLogger(__name__)

# Active ride statuses that should trigger room auto-join
ACTIVE_RIDE_STATUSES = ['scheduled', 'driver_en_route', 'arrived', 'in_progress', 'ACTIVE', 'FULL']


def register_socket_handlers(socketio):
    """Register all WebSocket event handlers."""

    @socketio.on('connect')
    def handle_connect():
        """Handle client connection. Auto-joins user to their active ride rooms."""
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
                
                # Auto-join user to their active ride rooms
                _auto_join_ride_rooms(user_id)
                
                emit('connection_response', {'data': 'Connected to server'})
            except Exception as e:
                logger.warning(f'Invalid token on connect: {e}')
                return False  # Reject connection
                
        except Exception as e:
            logger.error(f'Error in connect handler: {e}')
            return False
    
    def _auto_join_ride_rooms(user_id):
        """Auto-join user to rooms for their active rides (as driver or confirmed passenger)."""
        try:
            from app.models import Ride, Reservation
            
            # Rides where user is driver
            driver_rides = Ride.query.filter(
                Ride.driver_id == user_id,
                Ride.status.in_(ACTIVE_RIDE_STATUSES),
                Ride.is_deleted == False
            ).all()
            
            for ride in driver_rides:
                room = f'ride_{ride.id}'
                join_room(room)
                logger.info(f'Auto-joined user {user_id} (driver) to room {room}')
            
            # Rides where user is confirmed passenger
            confirmed_reservations = Reservation.query.filter(
                Reservation.employee_id == user_id,
                Reservation.status == 'CONFIRMED'
            ).all()
            
            for reservation in confirmed_reservations:
                ride = Ride.query.get(reservation.ride_id)
                if ride and ride.status in ACTIVE_RIDE_STATUSES and not ride.is_deleted:
                    room = f'ride_{ride.id}'
                    join_room(room)
                    logger.info(f'Auto-joined user {user_id} (passenger) to room {room}')
                    
        except Exception as e:
            logger.error(f'Error auto-joining ride rooms for user {user_id}: {e}')

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

    @socketio.on('update_driver_location')
    def on_update_driver_location(data):
        """
        Handle real-time driver location updates.
        
        Expected data: {
            'ride_id': <int>,
            'lat': <float>,
            'lng': <float>,
            'timestamp': <ISO string>
        }
        
        Security:
        - Only ride driver can send updates
        - Ride must be in active status (driver_en_route or in_progress)
        - Validates ride exists
        
        Broadcasts to ride room as 'driver_location_updated' event.
        Does NOT store in database - real-time only.
        """
        try:
            # Extract payload
            ride_id = data.get('ride_id')
            lat = data.get('lat')
            lng = data.get('lng')
            timestamp = data.get('timestamp')
            
            # Validate required fields
            if not all([ride_id, lat is not None, lng is not None, timestamp]):
                logger.warning(f'Invalid location update payload: {data}')
                emit('error', {
                    'message': 'Missing required fields: ride_id, lat, lng, timestamp'
                })
                return
            
            # Get JWT token to identify sender
            token = request.args.get('token')
            if not token:
                logger.warning('Location update without token')
                emit('error', {'message': 'Authentication required'})
                return
            
            try:
                decoded = decode_token(token)
                user_id = int(decoded['sub'])
            except Exception as e:
                logger.warning(f'Invalid token for location update: {e}')
                emit('error', {'message': 'Invalid authentication token'})
                return
            
            # Validate ride exists
            from app.models import Ride
            ride = Ride.query.get(ride_id)
            
            if not ride:
                logger.warning(f'Location update for non-existent ride {ride_id}')
                emit('error', {'message': f'Ride {ride_id} not found'})
                return
            
            # Security: Verify sender is the ride driver
            if ride.driver_id != user_id:
                logger.warning(
                    f'Unauthorized location update: User {user_id} is not driver '
                    f'of ride {ride_id} (driver is {ride.driver_id})'
                )
                emit('error', {
                    'message': 'Only the ride driver can send location updates'
                })
                return
            
            # Validate ride status - only allow during active ride
            valid_statuses = ['driver_en_route', 'in_progress']
            if ride.status.lower() not in valid_statuses:
                logger.warning(
                    f'Location update rejected: Ride {ride_id} status is '
                    f'{ride.status}, must be driver_en_route or in_progress'
                )
                emit('error', {
                    'message': f'Location updates only allowed during active ride '
                    f'(current status: {ride.status})'
                })
                return
            
            # Log the location update
            logger.info(
                f'Driver location update: Driver {user_id}, Ride {ride_id}, '
                f'Coordinates ({lat}, {lng}), Timestamp {timestamp}'
            )
            
            # Broadcast to ride room
            room = f'ride_{ride_id}'
            payload = {
                'ride_id': ride_id,
                'lat': lat,
                'lng': lng,
                'timestamp': timestamp
            }
            
            socketio.emit(
                'driver_location_updated',
                payload,
                room=room
            )
            
            logger.info(
                f'Broadcasted driver_location_updated to room {room}: '
                f'({lat}, {lng})'
            )
            
            # Acknowledge to sender
            emit('location_update_ack', {
                'ride_id': ride_id,
                'message': 'Location update broadcasted successfully'
            })
            
        except Exception as e:
            logger.error(f'Error in update_driver_location handler: {e}')
            emit('error', {'message': f'Failed to process location update: {str(e)}'})


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
