from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required
from datetime import datetime

from app.extensions import db
from app.models import Ride, Employee

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
