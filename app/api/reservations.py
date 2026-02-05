from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity

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
    @api.doc('create_reservation', security='Bearer', description='Book a seat on a ride. Validates: no duplicate active bookings, sufficient seats available.')
    @api.expect(reservation_create)
    @api.marshal_with(reservation_response)
    def post(self):
        """Book a seat on a ride with validation and atomic transaction"""
        data = request.get_json() or {}
        seats_reserved = data.get('seats_reserved', 1)
        
        # Validate seats_reserved
        if not isinstance(seats_reserved, int) or seats_reserved <= 0:
            api.abort(400, 'seats_reserved must be a positive integer greater than 0')

        ride_id = data.get('ride_id')
        employee_id = data.get('employee_id')
        
        if not ride_id or not employee_id:
            api.abort(400, 'ride_id and employee_id are required')

        # Atomic transaction - all or nothing
        try:
            # Use database lock to prevent race conditions
            ride = Ride.query.with_for_update().get(ride_id)
            if not ride:
                db.session.rollback()
                api.abort(404, 'Ride not found')

            # Check duplicate active reservation
            existing_reservation = Reservation.query.filter_by(
                employee_id=employee_id,
                ride_id=ride_id
            ).filter(Reservation.status != 'CANCELLED').first()
            
            if existing_reservation:
                db.session.rollback()
                api.abort(400, 'You already have an active reservation for this ride')

            # Validate ride status
            if ride.status == 'COMPLETED':
                db.session.rollback()
                api.abort(400, 'Cannot book a completed ride')
            
            if ride.status == 'FULL':
                db.session.rollback()
                api.abort(400, 'Ride is already full')

            # Strict seat enforcement
            if seats_reserved > ride.available_seats:
                db.session.rollback()
                api.abort(400, f'Not enough seats available. Requested: {seats_reserved}, Available: {ride.available_seats}')

            # Update ride seats
            ride.available_seats -= seats_reserved
            
            # Mark ride as FULL if no seats left
            if ride.available_seats == 0:
                ride.status = 'FULL'

            # Create reservation
            reservation = Reservation(
                employee_id=employee_id,
                ride_id=ride.id,
                seats_reserved=seats_reserved,
                status='CONFIRMED'
            )
            db.session.add(reservation)
            db.session.flush()

            # Create notification
            notification = Notification(
                employee_id=employee_id,
                ride_id=ride.id,
                message=f'Reservation confirmed for {ride.origin} → {ride.destination} (Ride #{ride.id})',
                is_read=False
            )
            db.session.add(notification)
            
            # Commit all changes atomically
            db.session.commit()
            return reservation, 201
            
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Booking failed: {str(e)}')


@api.route('/<int:id>/cancel')
@api.param('id', 'Reservation ID')
class ReservationCancel(Resource):
    @jwt_required()
    @api.doc('cancel_reservation', security='Bearer', description='Cancel a reservation (only by creator). Sets status to CANCELLED and restores seats.')
    @api.marshal_with(reservation_response)
    def post(self, id):
        """Cancel a reservation (only the creator can cancel)"""
        employee_id = int(get_jwt_identity())
        reservation = Reservation.query.get(id)
        
        if not reservation:
            api.abort(404, 'Reservation not found')
        
        # Only creator can cancel
        if reservation.employee_id != employee_id:
            api.abort(403, 'Only the reservation creator can cancel it')
        
        # Already cancelled
        if reservation.status == 'CANCELLED':
            api.abort(400, 'Reservation is already cancelled')
        
        # Restore available seats
        ride = Ride.query.get(reservation.ride_id)
        if ride:
            ride.available_seats += reservation.seats_reserved
            # Mark ride as ACTIVE again if it was FULL
            if ride.status == 'FULL':
                ride.status = 'ACTIVE'
        
        # Set status to CANCELLED (don't delete)
        reservation.status = 'CANCELLED'
        db.session.commit()
        
        return reservation, 200


@api.route('/<int:id>')
@api.param('id', 'Reservation ID')
class ReservationDetail(Resource):
    @jwt_required()
    @api.doc('delete_reservation', security='Bearer', description='Delete a reservation by ID')
    def delete(self, id):
        """Delete a reservation by ID"""
        reservation = Reservation.query.get(id)
        if not reservation:
            api.abort(404, 'Reservation not found')
        
        # Restore available seats
        ride = Ride.query.get(reservation.ride_id)
        if ride:
            ride.available_seats += reservation.seats_reserved
        
        db.session.delete(reservation)
        db.session.commit()
        return {'message': 'Reservation deleted successfully'}, 200
