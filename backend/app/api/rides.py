from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime
from werkzeug.exceptions import HTTPException
import logging

from app.extensions import db, socketio
from app.models import Ride, Employee, Reservation, Notification
from app.utils.logger import log_action
from app.utils.geo import matches_ride_location, PICKUP_RADIUS_KM, DESTINATION_RADIUS_KM
from app.realtime_events import emit_ride_status_update
from app.services.ride_expiration_service import check_and_expire_rides
from app.services.boarding_service import set_boarding_deadlines, check_and_expire_boarding_deadlines
from app.services.ride_auto_termination_service import check_and_terminate_rides

logger = logging.getLogger(__name__)

api = Namespace('rides', description='Ride operations')

# Error response model
error_response = api.model('ErrorResponse', {
    'error': fields.String(description='Error code (e.g., VALIDATION_ERROR, NOT_FOUND, UNAUTHORIZED, FORBIDDEN, INTERNAL_ERROR)'),
    'message': fields.String(description='Human readable error message')
})

ride_create = api.model('RideCreate', {
    'driver_id': fields.Integer(required=True, description='Employee ID of the driver'),
    'origin': fields.String(required=True, description='Pickup location'),
    'destination': fields.String(required=True, description='Drop-off location'),
    'origin_lat': fields.Float(required=False, description='Origin latitude'),
    'origin_lng': fields.Float(required=False, description='Origin longitude'),
    'destination_lat': fields.Float(required=False, description='Destination latitude'),
    'destination_lng': fields.Float(required=False, description='Destination longitude'),
    'departure_time': fields.DateTime(required=True, description='Departure datetime (ISO)'),
    'available_seats': fields.Integer(required=True, description='Seats available')
})

ride_response = api.model('RideResponse', {
    'id': fields.Integer(description='Ride ID'),
    'driver_id': fields.Integer(description='Employee ID of the driver'),
    'driver_name': fields.String(description='Driver name'),
    'driver_car_model': fields.String(description='Driver car model'),
    'driver_car_color': fields.String(description='Driver car color'),
    'origin': fields.String(description='Pickup location'),
    'destination': fields.String(description='Drop-off location'),
    'origin_lat': fields.Float(description='Origin latitude'),
    'origin_lng': fields.Float(description='Origin longitude'),
    'destination_lat': fields.Float(description='Destination latitude'),
    'destination_lng': fields.Float(description='Destination longitude'),
    'departure_time': fields.DateTime(description='Departure datetime (ISO)'),
    'available_seats': fields.Integer(description='Seats available'),
    'status': fields.String(description='Ride status (ACTIVE/FULL/COMPLETED)'),
    'created_at': fields.DateTime(description='Creation timestamp'),
    'reservations': fields.List(fields.Raw, description='List of reservation requests with passenger details')
})

participant_response = api.model('ParticipantResponse', {
    'employee_id': fields.Integer(description='Employee ID'),
    'name': fields.String(description='Employee name'),
    'email': fields.String(description='Employee email'),
    'seats_reserved': fields.Integer(description='Seats reserved by this employee'),
    'reservation_status': fields.String(description='Reservation status (CONFIRMED)')
})

# Paginated response model
paginated_rides_response = api.model('PaginatedRidesResponse', {
    'items': fields.List(fields.Nested(ride_response)),
    'page': fields.Integer(description='Current page number'),
    'per_page': fields.Integer(description='Items per page'),
    'total_items': fields.Integer(description='Total number of items'),
    'total_pages': fields.Integer(description='Total number of pages')
})


def serialize_ride_with_reservations(ride):
    """Helper function to serialize a ride with its reservations"""
    # Fetch reservations with passenger details
    reservations = db.session.query(
        Reservation.id,
        Reservation.employee_id,
        Reservation.seats_reserved,
        Reservation.status,
        Reservation.boarding_deadline,
        Reservation.boarded,
        Reservation.created_at,
        Employee.name,
        Employee.email
    ).join(
        Employee, Reservation.employee_id == Employee.id
    ).filter(
        Reservation.ride_id == ride.id
    ).all()
    
    # Get driver name and car info
    driver = Employee.query.get(ride.driver_id)
    driver_name = driver.name if driver else None
    driver_car_model = driver.car_model if driver else None
    driver_car_color = driver.car_color if driver else None
    
    return {
        'id': ride.id,
        'driver_id': ride.driver_id,
        'driver_name': driver_name,
        'driver_car_model': driver_car_model,
        'driver_car_color': driver_car_color,
        'origin': ride.origin,
        'destination': ride.destination,
        'origin_lat': ride.origin_lat,
        'origin_lng': ride.origin_lng,
        'destination_lat': ride.destination_lat,
        'destination_lng': ride.destination_lng,
        'departure_time': ride.departure_time.isoformat() if ride.departure_time else None,
        'available_seats': ride.available_seats,
        'status': ride.status,
        'created_at': ride.created_at.isoformat() if ride.created_at else None,
        'reservations': [
            {
                'id': r.id,
                'employee_id': r.employee_id,
                'seats_reserved': r.seats_reserved,
                'status': r.status,
                'boarding_deadline': r.boarding_deadline.isoformat() if r.boarding_deadline else None,
                'boarded': r.boarded,
                'created_at': r.created_at.isoformat() if r.created_at else None,
                'passenger_name': r.name,
                'passenger_email': r.email
            }
            for r in reservations
        ]
    }


def serialize_rides_list(rides):
    """Helper function to serialize a list of rides with reservations"""
    return [serialize_ride_with_reservations(ride) for ride in rides]

@api.route('/')
class RideList(Resource):
    @jwt_required()
    @api.doc('list_rides', security='Bearer', 
        params={
            'origin_lat': {'description': 'Search origin latitude (coordinate-based matching)', 'type': 'number', 'required': False},
            'origin_lng': {'description': 'Search origin longitude (coordinate-based matching)', 'type': 'number', 'required': False},
            'destination_lat': {'description': 'Search destination latitude (coordinate-based matching)', 'type': 'number', 'required': False},
            'destination_lng': {'description': 'Search destination longitude (coordinate-based matching)', 'type': 'number', 'required': False},
            'pickup_radius_km': {'description': f'Pickup radius in km (default: {PICKUP_RADIUS_KM})', 'type': 'number', 'required': False},
            'destination_radius_km': {'description': f'Destination radius in km (default: {DESTINATION_RADIUS_KM})', 'type': 'number', 'required': False},
            'date_from': {'description': 'Filter rides from this date (ISO datetime)', 'type': 'string', 'required': False},
            'date_to': {'description': 'Filter rides up to this date (ISO datetime)', 'type': 'string', 'required': False},
            'driver_id': {'description': 'Filter by driver ID (for getting my offered rides)', 'type': 'integer', 'required': False},
            'sort_by': {'description': 'Sort results: date_asc (default) or date_desc', 'type': 'string', 'required': False, 'enum': ['date_asc', 'date_desc']},
            'page': {'description': 'Page number (default: 1)', 'type': 'integer', 'required': False, 'default': 1},
            'per_page': {'description': 'Items per page (default: 10, max: 50)', 'type': 'integer', 'required': False, 'default': 10}
        },
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(paginated_rides_response)
    def get(self):
        """List all rides with optional filtering, sorting, and pagination"""
        # Lazy expiration and termination checks
        try:
            check_and_expire_rides()
            check_and_expire_boarding_deadlines()
            check_and_terminate_rides()
        except Exception as e:
            # Log but don't fail the request
            import logging
            logging.getLogger(__name__).error(f'Expiration/termination check failed: {e}')
        
        # Base query: exclude soft-deleted rides
        query = Ride.query.filter(Ride.is_deleted == False)
        
        # Coordinate-based location filters (replaces string-based matching)
        origin_lat = request.args.get('origin_lat', type=float)
        origin_lng = request.args.get('origin_lng', type=float)
        destination_lat = request.args.get('destination_lat', type=float)
        destination_lng = request.args.get('destination_lng', type=float)
        
        # Validate coordinate parameters - both lat and lng must be provided together
        has_origin_coords = origin_lat is not None and origin_lng is not None
        has_dest_coords = destination_lat is not None and destination_lng is not None
        
        # Validate that if one coordinate is provided, both must be provided
        if (origin_lat is not None) != (origin_lng is not None):
            api.abort(400, 'Both origin_lat and origin_lng must be provided together')
        if (destination_lat is not None) != (destination_lng is not None):
            api.abort(400, 'Both destination_lat and destination_lng must be provided together')
        
        # For passenger search (when ANY coordinates are provided), exclude terminal and begun rides
        # Only show rides that are available for booking: scheduled, driver_en_route, arrived
        # Exclude: completed, missed, in_progress (ride has begun), cancelled
        is_passenger_search = has_origin_coords or has_dest_coords
        
        if is_passenger_search:
            # Exclude rides that are completed, missed, in_progress, or cancelled
            query = query.filter(
                Ride.status.notin_(['completed', 'missed', 'in_progress', 'cancelled'])
            )
        
        # Optional custom radii (use defaults if not provided)
        pickup_radius = request.args.get('pickup_radius_km', type=float, default=PICKUP_RADIUS_KM)
        destination_radius = request.args.get('destination_radius_km', type=float, default=DESTINATION_RADIUS_KM)
        
        # Store coordinate search params for post-query filtering
        # Support three scenarios: origin-only, destination-only, or both
        coordinate_search = None
        if has_origin_coords or has_dest_coords:
            coordinate_search = {
                'origin_lat': origin_lat,
                'origin_lng': origin_lng,
                'destination_lat': destination_lat,
                'destination_lng': destination_lng,
                'pickup_radius_km': pickup_radius,
                'destination_radius_km': destination_radius,
                'has_origin': has_origin_coords,
                'has_dest': has_dest_coords
            }

        # Driver filter (for getting my offered rides)
        driver_id = request.args.get('driver_id')
        if driver_id:
            try:
                query = query.filter(Ride.driver_id == int(driver_id))
            except ValueError:
                api.abort(400, 'driver_id must be an integer')

        # Date range filters - support both date-only and datetime formats
        date_from = request.args.get('date_from')
        date_to = request.args.get('date_to')

        if date_from:
            try:
                # Handle both date-only (YYYY-MM-DD) and datetime formats
                if 'T' in date_from:
                    date_from_dt = datetime.fromisoformat(date_from.replace('Z', '+00:00'))
                else:
                    # Parse date-only format and set to start of day
                    date_from_dt = datetime.fromisoformat(f'{date_from}T00:00:00')
                query = query.filter(Ride.departure_time >= date_from_dt)
            except ValueError:
                api.abort(400, 'Invalid date_from format. Use ISO date (YYYY-MM-DD) or datetime (2026-02-10T10:00:00)')

        if date_to:
            try:
                # Handle both date-only (YYYY-MM-DD) and datetime formats
                if 'T' in date_to:
                    date_to_dt = datetime.fromisoformat(date_to.replace('Z', '+00:00'))
                else:
                    # Parse date-only format and set to end of day
                    date_to_dt = datetime.fromisoformat(f'{date_to}T23:59:59')
                query = query.filter(Ride.departure_time <= date_to_dt)
            except ValueError:
                api.abort(400, 'Invalid date_to format. Use ISO date (YYYY-MM-DD) or datetime (2026-02-10T10:00:00)')

        # Validate date range
        if date_from and date_to:
            try:
                if 'T' in date_from:
                    date_from_dt = datetime.fromisoformat(date_from.replace('Z', '+00:00'))
                else:
                    date_from_dt = datetime.fromisoformat(f'{date_from}T00:00:00')
                
                if 'T' in date_to:
                    date_to_dt = datetime.fromisoformat(date_to.replace('Z', '+00:00'))
                else:
                    date_to_dt = datetime.fromisoformat(f'{date_to}T23:59:59')
                
                if date_from_dt > date_to_dt:
                    api.abort(400, 'date_from cannot be later than date_to')
            except ValueError:
                api.abort(400, 'Invalid date format in range validation')

        # Sorting
        sort_by = request.args.get('sort_by', 'date_asc')
        if sort_by == 'date_desc':
            query = query.order_by(Ride.departure_time.desc())
        else:
            query = query.order_by(Ride.departure_time.asc())

        # Apply coordinate-based filtering BEFORE pagination
        # This ensures accurate pagination counts
        if coordinate_search:
            all_rides = query.all()
            filtered_rides = []
            
            for ride in all_rides:
                if matches_ride_location(
                    coordinate_search['origin_lat'],
                    coordinate_search['origin_lng'],
                    coordinate_search['destination_lat'],
                    coordinate_search['destination_lng'],
                    ride.origin_lat,
                    ride.origin_lng,
                    ride.destination_lat,
                    ride.destination_lng,
                    coordinate_search['pickup_radius_km'],
                    coordinate_search['destination_radius_km']
                ):
                    filtered_rides.append(ride)
            
            # Manual pagination on filtered results
            try:
                page = int(request.args.get('page', 1))
                per_page = int(request.args.get('per_page', 10))
            except ValueError:
                api.abort(400, 'page and per_page must be integers')
            
            if page < 1:
                api.abort(400, 'page must be >= 1')
            if per_page < 1 or per_page > 50:
                api.abort(400, 'per_page must be between 1 and 50')
            
            total_items = len(filtered_rides)
            total_pages = (total_items + per_page - 1) // per_page if total_items > 0 else 1
            start_idx = (page - 1) * per_page
            end_idx = start_idx + per_page
            page_items = filtered_rides[start_idx:end_idx]
            
            # Create pagination-like object
            class ManualPagination:
                def __init__(self, items, page, per_page, total):
                    self.items = items
                    self.page = page
                    self.per_page = per_page
                    self.total = total
                    self.pages = (total + per_page - 1) // per_page if total > 0 else 1
            
            pagination = ManualPagination(page_items, page, per_page, total_items)
        else:
            # No coordinate filtering - use standard pagination
            try:
                page = int(request.args.get('page', 1))
                per_page = int(request.args.get('per_page', 10))
            except ValueError:
                api.abort(400, 'page and per_page must be integers')

            if page < 1:
                api.abort(400, 'page must be >= 1')
            if per_page < 1 or per_page > 50:
                api.abort(400, 'per_page must be between 1 and 50')

            pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        
        serialized_items = serialize_rides_list(pagination.items)
        
        # Debug: Log coordinates in response
        for item in serialized_items:
            print(f"DEBUG: Returning ride {item['id']} with coordinates: "
                  f"origin_lat={item.get('origin_lat')}, origin_lng={item.get('origin_lng')}")

        return {
            'items': serialized_items,
            'page': pagination.page,
            'per_page': pagination.per_page,
            'total_items': pagination.total,
            'total_pages': pagination.pages
        }

    @jwt_required()
    @api.doc('create_ride', security='Bearer',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            404: ('Driver not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.expect(ride_create)
    @api.marshal_with(ride_response)
    def post(self):
        """Offer a new ride"""
        data = request.get_json()
        if data.get('available_seats', 0) <= 0:
            api.abort(400, 'available_seats must be greater than 0')
        
        # Get driver_id from JWT token instead of request body
        driver_id = int(get_jwt_identity())
        driver = Employee.query.get(driver_id)
        if not driver:
            api.abort(404, 'Driver not found')
        
        # Part 4: Validate departure_time is in the future
        departure_time = datetime.fromisoformat(data['departure_time'])
        if departure_time <= datetime.utcnow():
            api.abort(400, 'Departure time must be in the future. Cannot create rides with past departure times.')
        
        ride = Ride(
            driver_id=driver_id,
            origin=data['origin'],
            destination=data['destination'],
            origin_lat=data.get('origin_lat'),
            origin_lng=data.get('origin_lng'),
            destination_lat=data.get('destination_lat'),
            destination_lng=data.get('destination_lng'),
            departure_time=departure_time,
            available_seats=data['available_seats']
        )
        db.session.add(ride)
        db.session.commit()

        # Log ride creation
        log_action(
            action='RIDE_CREATED',
            employee_id=driver_id,
            details={'ride_id': ride.id, 'origin': ride.origin, 'destination': ride.destination}
        )

        return ride, 201


@api.route('/<int:id>')
@api.param('id', 'Ride ID')
class RideDetail(Resource):
    @jwt_required()
    @api.doc('get_ride', security='Bearer', description='Get a single ride by ID',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def get(self, id):
        """Get a single ride by ID"""
        # Lazy termination check
        try:
            check_and_terminate_rides()
        except Exception as e:
            logger.error(f'Termination check failed: {e}')
        
        ride = Ride.query.get(id)
        if not ride:
            api.abort(404, 'Ride not found')
        return serialize_ride_with_reservations(ride)

    @jwt_required()
    @api.doc('delete_ride', security='Bearer', description='Soft delete a ride (only by driver). Only allowed for completed or cancelled rides.',
        responses={
            400: ('Validation error - ride must be completed or cancelled', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can delete', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def delete(self, id):
        """Soft delete a ride (only the driver can delete completed or cancelled rides)"""
        employee_id = int(get_jwt_identity())
        
        try:
            ride = Ride.query.get(id)
            
            if not ride:
                api.abort(404, 'Ride not found')
            
            if ride.driver_id != employee_id:
                api.abort(403, 'Only the ride driver can delete the ride')
            
            # Only allow deletion of terminal state rides (completed, cancelled, missed)
            if ride.status not in ['completed', 'cancelled', 'missed', 'COMPLETED', 'CANCELLED']:
                api.abort(400, f'Cannot delete ride with status {ride.status}. Only completed, cancelled, or missed rides can be deleted.')
            
            # Soft delete - mark as deleted instead of removing from database
            ride.is_deleted = True
            db.session.commit()
            
            log_action(
                action='RIDE_DELETED',
                employee_id=employee_id,
                details={'ride_id': ride.id, 'status': ride.status, 'origin': ride.origin, 'destination': ride.destination}
            )
            
            return {'message': 'Ride deleted successfully', 'ride_id': ride.id}, 200
            
        except HTTPException:
            raise
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Failed to delete ride: {str(e)}')

    @jwt_required()
    @api.doc('update_ride', security='Bearer', description='Update ride details (only by driver). Cannot update COMPLETED rides.',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can update', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.expect(ride_create)
    @api.marshal_with(ride_response)
    def put(self, id):
        """Update a ride (only the driver can update)"""
        employee_id = int(get_jwt_identity())
        ride = Ride.query.get(id)
        
        if not ride:
            api.abort(404, 'Ride not found')
        
        # Only driver can update
        if ride.driver_id != employee_id:
            api.abort(403, 'Only the ride driver can update it')
        
        # Cannot update completed rides
        if ride.status == 'COMPLETED':
            api.abort(400, 'Cannot update a completed ride')
        
        data = request.get_json() or {}
        
        # Update fields if provided
        if 'origin' in data:
            ride.origin = data['origin']
        if 'destination' in data:
            ride.destination = data['destination']
        if 'departure_time' in data:
            ride.departure_time = datetime.fromisoformat(data['departure_time'])
        if 'available_seats' in data:
            # Check if new seats would be less than already reserved
            reserved_seats = db.session.query(db.func.sum(Reservation.seats_reserved)) \
                .filter_by(ride_id=ride.id, status='CONFIRMED') \
                .scalar() or 0
            
            new_seats = data['available_seats']
            if new_seats < reserved_seats:
                api.abort(400, f'Cannot set seats below already reserved amount ({reserved_seats})')
            
            ride.available_seats = new_seats
            # Update status if seats are available again
            if new_seats > 0 and ride.status == 'FULL':
                ride.status = 'ACTIVE'
        
        db.session.commit()
        return ride


@api.route('/<int:id>/start')
@api.param('id', 'Ride ID')
class RideStart(Resource):
    @jwt_required()
    @api.doc('start_ride', security='Bearer', description='Start ride - driver en route (only by driver). Transitions from scheduled to driver_en_route.',
        responses={
            400: ('Validation error - invalid state transition', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can start', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def patch(self, id):
        """Start ride - driver en route (only the driver can start)"""
        employee_id = int(get_jwt_identity())
        
        try:
            ride = Ride.query.get(id)
            
            if not ride:
                api.abort(404, 'Ride not found')
            
            if ride.driver_id != employee_id:
                api.abort(403, 'Only the ride driver can start the ride')
            
            if not ride.can_transition_to('driver_en_route'):
                api.abort(400, f'Cannot transition from {ride.status} to driver_en_route')
            
            ride.status = 'driver_en_route'
            db.session.commit()
            
            log_action(
                action='RIDE_STARTED',
                employee_id=employee_id,
                details={'ride_id': ride.id, 'new_status': 'driver_en_route'}
            )
            
            emit_ride_status_update(
                socketio,
                ride_id=ride.id,
                new_status=ride.status,
                updated_at=datetime.utcnow().isoformat()
            )
            
            return serialize_ride_with_reservations(ride), 200
            
        except HTTPException:
            raise
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Failed to start ride: {str(e)}')


@api.route('/<int:id>/arrive')
@api.param('id', 'Ride ID')
class RideArrive(Resource):
    @jwt_required()
    @api.doc('arrive_ride', security='Bearer', description='Mark driver as arrived (only by driver). Transitions from driver_en_route to arrived.',
        responses={
            400: ('Validation error - invalid state transition', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can mark arrival', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def patch(self, id):
        """Mark driver as arrived (only the driver can mark arrival)"""
        employee_id = int(get_jwt_identity())
        
        try:
            ride = Ride.query.get(id)
            
            if not ride:
                api.abort(404, 'Ride not found')
            
            if ride.driver_id != employee_id:
                api.abort(403, 'Only the ride driver can mark arrival')
            
            if not ride.can_transition_to('arrived'):
                api.abort(400, f'Cannot transition from {ride.status} to arrived')
            
            ride.status = 'arrived'
            db.session.commit()
            
            # Note: Boarding deadlines are NOT set here anymore
            # Passengers can confirm boarding anytime during 'arrived' status
            # Timer starts when driver presses "Begin Ride"
            
            log_action(
                action='RIDE_DRIVER_ARRIVED',
                employee_id=employee_id,
                details={'ride_id': ride.id, 'new_status': 'arrived'}
            )
            
            emit_ride_status_update(
                socketio,
                ride_id=ride.id,
                new_status=ride.status,
                updated_at=datetime.utcnow().isoformat()
            )
            
            return serialize_ride_with_reservations(ride), 200
            
        except HTTPException:
            raise
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Failed to mark arrival: {str(e)}')


@api.route('/<int:id>/begin')
@api.param('id', 'Ride ID')
class RideBegin(Resource):
    @jwt_required()
    @api.doc('begin_ride', security='Bearer', description='Begin ride journey (only by driver). Transitions from arrived to in_progress.',
        responses={
            400: ('Validation error - invalid state transition', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can begin ride', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def patch(self, id):
        """Begin ride journey (only the driver can begin)"""
        employee_id = int(get_jwt_identity())
        
        try:
            ride = Ride.query.get(id)
            
            if not ride:
                api.abort(404, 'Ride not found')
            
            if ride.driver_id != employee_id:
                api.abort(403, 'Only the ride driver can begin the ride')
            
            if not ride.can_transition_to('in_progress'):
                api.abort(400, f'Cannot transition from {ride.status} to in_progress')
            
            # NEW LOGIC: Set boarding deadlines NOW (when driver presses Begin Ride)
            # This starts the 5-minute timer for passengers who haven't confirmed yet
            # Passengers who already confirmed (boarded=True) won't get a deadline
            set_boarding_deadlines(ride.id)
            
            ride.status = 'in_progress'
            ride.updated_at = datetime.utcnow()
            db.session.commit()
            
            # Schedule a check for boarding deadline expiration
            # This will be handled by lazy evaluation on subsequent API calls
            logger.info(f'Ride {ride.id} began - boarding deadlines set for unconfirmed passengers')
            
            log_action(
                action='RIDE_BEGUN',
                employee_id=employee_id,
                details={'ride_id': ride.id, 'new_status': 'in_progress'}
            )
            
            emit_ride_status_update(
                socketio,
                ride_id=ride.id,
                new_status=ride.status,
                updated_at=datetime.utcnow().isoformat()
            )
            
            return serialize_ride_with_reservations(ride), 200
            
        except HTTPException:
            raise
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Failed to begin ride: {str(e)}')


@api.route('/<int:id>/complete')
@api.param('id', 'Ride ID')
class RideComplete(Resource):
    @jwt_required()
    @api.doc('complete_ride', security='Bearer', description='Complete ride (only by driver). Transitions from in_progress to completed. Updates all reservations to completed.',
        responses={
            400: ('Validation error - invalid state transition', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can complete', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def patch(self, id):
        """Complete ride (only the driver can complete)"""
        employee_id = int(get_jwt_identity())
        
        try:
            ride = Ride.query.get(id)
            
            if not ride:
                api.abort(404, 'Ride not found')
            
            if ride.driver_id != employee_id:
                api.abort(403, 'Only the ride driver can complete the ride')
            
            if not ride.can_transition_to('completed'):
                api.abort(400, f'Cannot transition from {ride.status} to completed')
            
            ride.status = 'completed'
            
            # Update all CONFIRMED reservations to completed
            reservations = Reservation.query.filter_by(
                ride_id=ride.id,
                status='CONFIRMED'
            ).all()
            
            for reservation in reservations:
                reservation.status = 'COMPLETED'
            
            db.session.commit()
            
            log_action(
                action='RIDE_COMPLETED',
                employee_id=employee_id,
                details={'ride_id': ride.id, 'new_status': 'completed', 'reservations_completed': len(reservations)}
            )
            
            emit_ride_status_update(
                socketio,
                ride_id=ride.id,
                new_status=ride.status,
                updated_at=datetime.utcnow().isoformat()
            )
            
            return serialize_ride_with_reservations(ride), 200
            
        except HTTPException:
            raise
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Failed to complete ride: {str(e)}')


@api.route('/<int:id>/cancel')
@api.param('id', 'Ride ID')
class RideCancel(Resource):
    @jwt_required()
    @api.doc('cancel_ride', security='Bearer', description='Cancel a ride (only by driver). Sets status to CANCELLED and cancels all reservations.',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can cancel', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def patch(self, id):
        """Cancel a ride (only the driver can cancel)"""
        employee_id = int(get_jwt_identity())
        
        try:
            ride = Ride.query.get(id)
            
            if not ride:
                api.abort(404, 'Ride not found')
            
            # Only driver can cancel
            if ride.driver_id != employee_id:
                api.abort(403, 'Only the ride driver can cancel it')
            
            # Can only cancel ACTIVE or FULL rides
            if ride.status == 'COMPLETED':
                api.abort(400, 'Cannot cancel a completed ride')
            
            if ride.status == 'CANCELLED':
                api.abort(400, 'Ride is already cancelled')
            
            # Update ride status to CANCELLED
            ride.status = 'CANCELLED'
            ride.cancelled_at = datetime.utcnow()
            
            short_destination = (ride.destination or '').split(',')[0].strip() or ride.destination
            
            # Cancel all PENDING and CONFIRMED reservations for this ride
            reservations = Reservation.query.filter_by(ride_id=ride.id).filter(
                Reservation.status.in_(['PENDING', 'CONFIRMED'])
            ).all()
            
            for reservation in reservations:
                reservation.status = 'CANCELLED'
                
                # Create notification for affected passenger
                notification = Notification(
                    employee_id=reservation.employee_id,
                    ride_id=ride.id,
                    message=f'Ride Cancelled: Your ride to {short_destination} has been cancelled by the driver.',
                    type='cancellation',
                    is_read=False
                )
                db.session.add(notification)
            
            db.session.commit()
            
            # Log ride cancellation
            log_action(
                action='RIDE_CANCELLED',
                employee_id=employee_id,
                details={'ride_id': ride.id, 'origin': ride.origin, 'destination': ride.destination, 'reservations_cancelled': len(reservations)}
            )
            
            # Emit real-time update for ride cancellation
            emit_ride_status_update(
                socketio,
                ride_id=ride.id,
                new_status=ride.status,
                updated_at=datetime.utcnow().isoformat()
            )
            
            return serialize_ride_with_reservations(ride), 200
            
        except HTTPException:
            # Re-raise HTTP exceptions (403, 404, 400) without modification
            raise
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Cancellation failed: {str(e)}')


@api.route('/<int:id>/participants')
@api.param('id', 'Ride ID')
class RideParticipants(Resource):
    @jwt_required()
    @api.doc('list_participants', security='Bearer', description='Get list of participants in a ride (driver only)',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can view participants', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(participant_response)
    def get(self, id):
        """List ride participants (only the driver can access)"""
        employee_id = int(get_jwt_identity())
        ride = Ride.query.get(id)
        
        if not ride:
            api.abort(404, 'Ride not found')
        
        # Only driver can view participants
        if ride.driver_id != employee_id:
            api.abort(403, 'Only the ride driver can view participants')
        
        # Join Employee, Reservation, and Ride tables to get participants
        participants = db.session.query(
            Employee.id.label('employee_id'),
            Employee.name,
            Employee.email,
            Reservation.seats_reserved,
            Reservation.status.label('reservation_status')
        ).join(
            Reservation, Employee.id == Reservation.employee_id
        ).filter(
            Reservation.ride_id == id,
            Reservation.status != 'CANCELLED'
        ).all()
        
        return [
            {
                'employee_id': p.employee_id,
                'name': p.name,
                'email': p.email,
                'seats_reserved': p.seats_reserved,
                'reservation_status': p.reservation_status
            }
            for p in participants
        ]


# Pending request response model
pending_request_response = api.model('PendingRequestResponse', {
    'employee_id': fields.Integer(description='Employee ID'),
    'name': fields.String(description='Employee name'),
    'email': fields.String(description='Employee email'),
    'seats_requested': fields.Integer(description='Seats requested'),
    'status': fields.String(description='Request status (PENDING)'),
    'requested_at': fields.DateTime(description='Request timestamp')
})


@api.route('/<int:id>/pending-requests')
@api.param('id', 'Ride ID')
class RidePendingRequests(Resource):
    @jwt_required()
    @api.doc('list_pending_requests', security='Bearer', description='Get list of pending reservation requests for a ride (driver only)',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can view pending requests', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(pending_request_response)
    def get(self, id):
        """List pending reservation requests (only the driver can access)"""
        employee_id = int(get_jwt_identity())
        ride = Ride.query.get(id)
        
        if not ride:
            api.abort(404, 'Ride not found')
        
        # Only driver can view pending requests
        if ride.driver_id != employee_id:
            api.abort(403, 'Only the ride driver can view pending requests')
        
        # Join Employee, Reservation, and Ride tables to get pending requests
        pending_requests = db.session.query(
            Employee.id.label('employee_id'),
            Employee.name,
            Employee.email,
            Reservation.seats_reserved.label('seats_requested'),
            Reservation.status.label('status'),
            Reservation.created_at.label('requested_at')
        ).join(
            Reservation, Employee.id == Reservation.employee_id
        ).filter(
            Reservation.ride_id == id,
            Reservation.status == 'PENDING'
        ).all()
        
        return [
            {
                'employee_id': pr.employee_id,
                'name': pr.name,
                'email': pr.email,
                'seats_requested': pr.seats_requested,
                'status': pr.status,
                'requested_at': pr.requested_at.isoformat() if pr.requested_at else None
            }
            for pr in pending_requests
        ]


# Pending request response model
pending_request_response = api.model('PendingRequestResponse', {
    'employee_id': fields.Integer(description='Employee ID'),
    'name': fields.String(description='Employee name'),
    'email': fields.String(description='Employee email'),
    'seats_requested': fields.Integer(description='Seats requested'),
    'status': fields.String(description='Request status (PENDING)'),
    'requested_at': fields.DateTime(description='Request timestamp')
})


@api.route('/<int:id>/pending-requests')
@api.param('id', 'Ride ID')
class RidePendingRequests(Resource):
    @jwt_required()
    @api.doc('list_pending_requests', security='Bearer', description='Get list of pending reservation requests for a ride (driver only)',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can view pending requests', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(pending_request_response)
    def get(self, id):
        """List pending reservation requests (only the driver can access)"""
        employee_id = int(get_jwt_identity())
        ride = Ride.query.get(id)
        
        if not ride:
            api.abort(404, 'Ride not found')
        
        # Only driver can view pending requests
        if ride.driver_id != employee_id:
            api.abort(403, 'Only the ride driver can view pending requests')
        
        # Join Employee, Reservation, and Ride tables to get pending requests
        pending_requests = db.session.query(
            Employee.id.label('employee_id'),
            Employee.name,
            Employee.email,
            Reservation.seats_reserved.label('seats_requested'),
            Reservation.status.label('status'),
            Reservation.created_at.label('requested_at')
        ).join(
            Reservation, Employee.id == Reservation.employee_id
        ).filter(
            Reservation.ride_id == id,
            Reservation.status == 'PENDING'
        ).all()
        
        return [
            {
                'employee_id': pr.employee_id,
                'name': pr.name,
                'email': pr.email,
                'seats_requested': pr.seats_requested,
                'status': pr.status,
                'requested_at': pr.requested_at.isoformat() if pr.requested_at else None
            }
            for pr in pending_requests
        ]
