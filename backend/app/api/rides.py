from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime

from app.extensions import db
from app.models import Ride, Employee, Reservation
from app.utils.logger import log_action

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
    'departure_time': fields.DateTime(required=True, description='Departure datetime (ISO)'),
    'available_seats': fields.Integer(required=True, description='Seats available')
})

ride_response = api.model('RideResponse', {
    'id': fields.Integer(description='Ride ID'),
    'driver_id': fields.Integer(description='Employee ID of the driver'),
    'origin': fields.String(description='Pickup location'),
    'destination': fields.String(description='Drop-off location'),
    'departure_time': fields.DateTime(description='Departure datetime (ISO)'),
    'available_seats': fields.Integer(description='Seats available'),
    'status': fields.String(description='Ride status (ACTIVE/FULL/COMPLETED)'),
    'created_at': fields.DateTime(description='Creation timestamp')
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

@api.route('/')
class RideList(Resource):
    @jwt_required()
    @api.doc('list_rides', security='Bearer', 
        params={
            'origin': {'description': 'Filter by origin (partial match, case-insensitive)', 'type': 'string', 'required': False},
            'destination': {'description': 'Filter by destination (partial match, case-insensitive)', 'type': 'string', 'required': False},
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
        query = Ride.query

        # Origin/destination filters
        origin = request.args.get('origin')
        destination = request.args.get('destination')

        if origin:
            query = query.filter(Ride.origin.ilike(f'%{origin}%'))

        if destination:
            query = query.filter(Ride.destination.ilike(f'%{destination}%'))

        # Driver filter (for getting my offered rides)
        driver_id = request.args.get('driver_id')
        if driver_id:
            try:
                query = query.filter(Ride.driver_id == int(driver_id))
            except ValueError:
                api.abort(400, 'driver_id must be an integer')

        # Date range filters
        date_from = request.args.get('date_from')
        date_to = request.args.get('date_to')

        if date_from:
            try:
                date_from_dt = datetime.fromisoformat(date_from.replace('Z', '+00:00'))
                query = query.filter(Ride.departure_time >= date_from_dt)
            except ValueError:
                api.abort(400, 'Invalid date_from format. Use ISO datetime (e.g., 2026-02-10T10:00:00)')

        if date_to:
            try:
                date_to_dt = datetime.fromisoformat(date_to.replace('Z', '+00:00'))
                query = query.filter(Ride.departure_time <= date_to_dt)
            except ValueError:
                api.abort(400, 'Invalid date_to format. Use ISO datetime (e.g., 2026-02-10T10:00:00)')

        # Validate date range
        if date_from and date_to:
            if datetime.fromisoformat(date_from.replace('Z', '+00:00')) > datetime.fromisoformat(date_to.replace('Z', '+00:00')):
                api.abort(400, 'date_from cannot be later than date_to')

        # Sorting
        sort_by = request.args.get('sort_by', 'date_asc')
        if sort_by == 'date_desc':
            query = query.order_by(Ride.departure_time.desc())
        else:
            query = query.order_by(Ride.departure_time.asc())

        # Pagination parameters
        try:
            page = int(request.args.get('page', 1))
            per_page = int(request.args.get('per_page', 10))
        except ValueError:
            api.abort(400, 'page and per_page must be integers')

        # Validate pagination
        if page < 1:
            api.abort(400, 'page must be >= 1')
        if per_page < 1 or per_page > 50:
            api.abort(400, 'per_page must be between 1 and 50')

        # Execute paginated query
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)

        return {
            'items': pagination.items,
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
        
        ride = Ride(
            driver_id=driver_id,
            origin=data['origin'],
            destination=data['destination'],
            departure_time=datetime.fromisoformat(data['departure_time']),
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
    @api.marshal_with(ride_response)
    def get(self, id):
        """Get a single ride by ID"""
        ride = Ride.query.get(id)
        if not ride:
            api.abort(404, 'Ride not found')
        return ride

    @jwt_required()
    @api.doc('delete_ride', security='Bearer', description='Delete a ride by ID',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    def delete(self, id):
        """Delete a ride by ID"""
        ride = Ride.query.get(id)
        if not ride:
            api.abort(404, 'Ride not found')
        db.session.delete(ride)
        db.session.commit()
        return {'message': 'Ride deleted successfully'}, 200

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


@api.route('/<int:id>/complete')
@api.param('id', 'Ride ID')
class RideComplete(Resource):
    @jwt_required()
    @api.doc('complete_ride', security='Bearer', description='Mark ride as COMPLETED (only by driver). Completed rides cannot be edited or booked.',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can complete', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(ride_response)
    def patch(self, id):
        """Mark a ride as completed (only the driver can complete)"""
        employee_id = int(get_jwt_identity())
        ride = Ride.query.get(id)
        
        if not ride:
            api.abort(404, 'Ride not found')
        
        # Only driver can complete
        if ride.driver_id != employee_id:
            api.abort(403, 'Only the ride driver can complete it')
        
        # Already completed
        if ride.status == 'COMPLETED':
            api.abort(400, 'Ride is already completed')
        
        ride.status = 'COMPLETED'
        db.session.commit()
        return ride


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
