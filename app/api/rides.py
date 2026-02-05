from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime

from app.extensions import db
from app.models import Ride, Employee, Reservation

api = Namespace('rides', description='Ride operations')

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

@api.route('/')
class RideList(Resource):
    @jwt_required()
    @api.doc('list_rides', security='Bearer', params={
        'origin': {'description': 'Filter by origin (partial match, case-insensitive)', 'type': 'string', 'required': False},
        'destination': {'description': 'Filter by destination (partial match, case-insensitive)', 'type': 'string', 'required': False}
    })
    @api.marshal_list_with(ride_response)
    def get(self):
        """List all rides or filter by origin/destination"""
        query = Ride.query

        origin = request.args.get('origin')
        destination = request.args.get('destination')

        if origin:
            query = query.filter(Ride.origin.ilike(f'%{origin}%'))

        if destination:
            query = query.filter(Ride.destination.ilike(f'%{destination}%'))

        rides = query.all()
        return rides

    @jwt_required()
    @api.doc('create_ride', security='Bearer')
    @api.expect(ride_create)
    @api.marshal_with(ride_response)
    def post(self):
        """Offer a new ride"""
        data = request.get_json()
        if data.get('available_seats', 0) <= 0:
            api.abort(400, 'available_seats must be greater than 0')
        driver = Employee.query.get(data['driver_id'])
        if not driver:
            api.abort(404, 'Driver not found')
        ride = Ride(
            driver_id=data['driver_id'],
            origin=data['origin'],
            destination=data['destination'],
            departure_time=datetime.fromisoformat(data['departure_time']),
            available_seats=data['available_seats']
        )
        db.session.add(ride)
        db.session.commit()
        return ride, 201


@api.route('/<int:id>')
@api.param('id', 'Ride ID')
class RideDetail(Resource):
    @jwt_required()
    @api.doc('get_ride', security='Bearer', description='Get a single ride by ID')
    @api.marshal_with(ride_response)
    def get(self, id):
        """Get a single ride by ID"""
        ride = Ride.query.get(id)
        if not ride:
            api.abort(404, 'Ride not found')
        return ride

    @jwt_required()
    @api.doc('delete_ride', security='Bearer', description='Delete a ride by ID')
    def delete(self, id):
        """Delete a ride by ID"""
        ride = Ride.query.get(id)
        if not ride:
            api.abort(404, 'Ride not found')
        db.session.delete(ride)
        db.session.commit()
        return {'message': 'Ride deleted successfully'}, 200

    @jwt_required()
    @api.doc('update_ride', security='Bearer', description='Update ride details (only by driver). Cannot update COMPLETED rides.')
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
    @api.doc('complete_ride', security='Bearer', description='Mark ride as COMPLETED (only by driver). Completed rides cannot be edited or booked.')
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
