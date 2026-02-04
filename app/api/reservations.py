from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required

from app.extensions import db
from app.models import Reservation, Ride, Employee, Notification

api = Namespace('reservations', description='Reservation operations')

reservation_create = api.model('ReservationCreate', {
    'employee_id': fields.Integer(required=True, description='Employee ID of the rider'),
    'ride_id': fields.Integer(required=True, description='Ride ID to reserve'),
    'seats_reserved': fields.Integer(required=False, default=1, description='Seats to reserve')
})

reservation_response = api.model('ReservationResponse', {
    'id': fields.Integer(description='Reservation ID'),
    'employee_id': fields.Integer(description='Employee ID of the rider'),
    'ride_id': fields.Integer(description='Ride ID reserved'),
    'seats_reserved': fields.Integer(description='Seats reserved'),
    'status': fields.String(description='Reservation status'),
    'created_at': fields.DateTime(description='Creation timestamp')
})

@api.route('/')
class ReservationList(Resource):
    @jwt_required()
    @api.doc('list_reservations', security='Bearer')
    @api.marshal_list_with(reservation_response)
    def get(self):
        """List all reservations"""
        reservations = Reservation.query.all()
        return reservations

    @jwt_required()
    @api.doc('create_reservation', security='Bearer')
    @api.expect(reservation_create)
    @api.marshal_with(reservation_response)
    def post(self):
        """Book a seat on a ride"""
        data = request.get_json() or {}
        seats_reserved = data.get('seats_reserved', 1)
        if seats_reserved <= 0:
            api.abort(400, 'seats_reserved must be greater than 0')

        ride = Ride.query.get(data.get('ride_id'))
        if not ride:
            api.abort(404, 'Ride not found')

        employee = Employee.query.get(data.get('employee_id'))
        if not employee:
            api.abort(404, 'Employee not found')

        if ride.available_seats < seats_reserved:
            api.abort(400, 'Not enough available seats')

        ride.available_seats -= seats_reserved

        reservation = Reservation(
            employee_id=employee.id,
            ride_id=ride.id,
            seats_reserved=seats_reserved,
            status='CONFIRMED'
        )
        db.session.add(reservation)
        db.session.flush()

        notification = Notification(
            employee_id=employee.id,
            ride_id=ride.id,
            message=f'Reservation confirmed for {ride.origin} → {ride.destination} (Ride #{ride.id})',
            is_read=False
        )
        db.session.add(notification)
        db.session.commit()
        return reservation, 201
