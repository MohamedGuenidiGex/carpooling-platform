from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity
from werkzeug.exceptions import HTTPException

from app.extensions import db
from app.models import Reservation, Ride, Employee, Notification
from app.utils.logger import log_action

api = Namespace('reservations', description='Reservation operations')

# Error response model
error_response = api.model('ErrorResponse', {
    'error': fields.String(description='Error code (e.g., VALIDATION_ERROR, NOT_FOUND, UNAUTHORIZED, FORBIDDEN, INTERNAL_ERROR)'),
    'message': fields.String(description='Human readable error message')
})

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
    'status': fields.String(description='Reservation status (PENDING/CONFIRMED/CANCELLED/REJECTED)'),
    'created_at': fields.DateTime(description='Creation timestamp')
})

@api.route('/')
class ReservationList(Resource):
    @jwt_required()
    @api.doc('list_reservations', security='Bearer',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_list_with(reservation_response)
    def get(self):
        """List all reservations"""
        reservations = Reservation.query.all()
        return reservations

    @jwt_required()
    @api.doc('create_reservation', security='Bearer', description='Request a seat on a ride. Creates PENDING reservation. Driver must approve.',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            404: ('Ride not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.expect(reservation_create)
    @api.marshal_with(reservation_response)
    def post(self):
        """Request a seat on a ride (creates PENDING reservation, driver approval required)"""
        data = request.get_json() or {}
        seats_reserved = data.get('seats_reserved', 1)
        
        # Validate seats_reserved
        if not isinstance(seats_reserved, int) or seats_reserved <= 0:
            api.abort(400, 'seats_reserved must be a positive integer greater than 0')

        ride_id = data.get('ride_id')
        employee_id = data.get('employee_id')
        
        if not ride_id or not employee_id:
            api.abort(400, 'ride_id and employee_id are required')

        try:
            ride = Ride.query.get(ride_id)
            if not ride:
                api.abort(404, 'Ride not found')

            # Check duplicate active reservation (PENDING or CONFIRMED)
            existing_reservation = Reservation.query.filter_by(
                employee_id=employee_id,
                ride_id=ride_id
            ).filter(Reservation.status.in_(['PENDING', 'CONFIRMED'])).first()
            
            if existing_reservation:
                api.abort(400, 'You already have an active reservation for this ride')

            # Validate ride status
            if ride.status == 'COMPLETED':
                api.abort(400, 'Cannot book a completed ride')
            
            if ride.status == 'FULL':
                api.abort(400, 'Ride is already full')

            # Strict seat enforcement (check if seats would be available if approved)
            if seats_reserved > ride.available_seats:
                api.abort(400, f'Not enough seats available. Requested: {seats_reserved}, Available: {ride.available_seats}')

            # Create reservation with PENDING status (no seat deduction yet)
            reservation = Reservation(
                employee_id=employee_id,
                ride_id=ride.id,
                seats_reserved=seats_reserved,
                status='PENDING'
            )
            db.session.add(reservation)
            db.session.flush()

            # Create notification for the requesting employee
            notification = Notification(
                employee_id=employee_id,
                ride_id=ride.id,
                message=f'Reservation request pending for {ride.origin} → {ride.destination} (Ride #{ride.id}). Waiting for driver approval.',
                is_read=False
            )
            db.session.add(notification)
            
            # Create notification for the driver
            driver_notification = Notification(
                employee_id=ride.driver_id,
                ride_id=ride.id,
                message=f'New reservation request for your ride {ride.origin} → {ride.destination} (Ride #{ride.id}). Employee #{employee_id} requested {seats_reserved} seat(s).',
                is_read=False
            )
            db.session.add(driver_notification)
            
            db.session.commit()

            # Log reservation creation
            log_action(
                action='RESERVATION_CREATED',
                employee_id=employee_id,
                details={'reservation_id': reservation.id, 'ride_id': ride_id, 'seats_reserved': seats_reserved, 'status': 'PENDING'}
            )

            return reservation, 201
            
        except HTTPException:
            # Re-raise HTTP exceptions (400, 403, 404) without modification
            raise
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Booking request failed: {str(e)}')


@api.route('/<int:id>/cancel')
@api.param('id', 'Reservation ID')
class ReservationCancel(Resource):
    @jwt_required()
    @api.doc('cancel_reservation', security='Bearer', description='Cancel a reservation (only by creator). Sets status to CANCELLED and restores seats (only if CONFIRMED).',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only creator can cancel', error_response),
            404: ('Reservation not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
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
        
        # Already cancelled or rejected
        if reservation.status in ['CANCELLED', 'REJECTED']:
            api.abort(400, f'Reservation is already {reservation.status.lower()}')
        
        # Restore available seats only if reservation was CONFIRMED
        if reservation.status == 'CONFIRMED':
            ride = Ride.query.get(reservation.ride_id)
            if ride:
                ride.available_seats += reservation.seats_reserved
                # Mark ride as ACTIVE again if it was FULL
                if ride.status == 'FULL':
                    ride.status = 'ACTIVE'
        
        # Set status to CANCELLED (don't delete)
        reservation.status = 'CANCELLED'
        db.session.commit()

        # Log reservation cancellation
        log_action(
            action='RESERVATION_CANCELLED',
            employee_id=employee_id,
            details={'reservation_id': reservation.id, 'ride_id': reservation.ride_id, 'seats_reserved': reservation.seats_reserved}
        )
        
        return reservation, 200


@api.route('/<int:id>/approve')
@api.param('id', 'Reservation ID')
class ReservationApprove(Resource):
    @jwt_required()
    @api.doc('approve_reservation', security='Bearer', description='Approve a PENDING reservation (driver only). Deducts seats and sets status to CONFIRMED.',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can approve', error_response),
            404: ('Reservation not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(reservation_response)
    def patch(self, id):
        """Approve a reservation (only the ride driver can approve)"""
        employee_id = int(get_jwt_identity())
        
        try:
            # Get reservation with ride locked for update
            reservation = Reservation.query.get(id)
            if not reservation:
                api.abort(404, 'Reservation not found')
            
            ride = Ride.query.with_for_update().get(reservation.ride_id)
            
            # Only driver can approve
            if ride.driver_id != employee_id:
                api.abort(403, 'Only the ride driver can approve reservations')
            
            # Can only approve PENDING reservations
            if reservation.status != 'PENDING':
                api.abort(400, f'Cannot approve reservation with status: {reservation.status}')
            
            # Check seat availability again
            if reservation.seats_reserved > ride.available_seats:
                api.abort(400, f'Not enough seats available. Required: {reservation.seats_reserved}, Available: {ride.available_seats}')
            
            # Deduct seats
            ride.available_seats -= reservation.seats_reserved
            
            # Mark ride as FULL if no seats left
            if ride.available_seats == 0:
                ride.status = 'FULL'
            
            # Update reservation status
            reservation.status = 'CONFIRMED'
            
            # Create notification for the employee
            notification = Notification(
                employee_id=reservation.employee_id,
                ride_id=ride.id,
                message=f'Reservation APPROVED for {ride.origin} → {ride.destination} (Ride #{ride.id}). {reservation.seats_reserved} seat(s) confirmed.',
                is_read=False
            )
            db.session.add(notification)
            
            db.session.commit()

            # Log reservation approval
            log_action(
                action='RESERVATION_APPROVED',
                employee_id=employee_id,
                details={'reservation_id': reservation.id, 'ride_id': ride.id, 'seats_reserved': reservation.seats_reserved}
            )

            return reservation, 200
            
        except HTTPException:
            # Re-raise HTTP exceptions (403, 404, 400) without modification
            raise
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Approval failed: {str(e)}')


@api.route('/<int:id>/reject')
@api.param('id', 'Reservation ID')
class ReservationReject(Resource):
    @jwt_required()
    @api.doc('reject_reservation', security='Bearer', description='Reject a PENDING reservation (driver only). Sets status to REJECTED. No seat changes.',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            403: ('Forbidden - Only ride driver can reject', error_response),
            404: ('Reservation not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(reservation_response)
    def patch(self, id):
        """Reject a reservation (only the ride driver can reject)"""
        employee_id = int(get_jwt_identity())
        
        try:
            reservation = Reservation.query.get(id)
            if not reservation:
                api.abort(404, 'Reservation not found')
            
            ride = Ride.query.get(reservation.ride_id)
            
            # Only driver can reject
            if ride.driver_id != employee_id:
                api.abort(403, 'Only the ride driver can reject reservations')
            
            # Can only reject PENDING reservations
            if reservation.status != 'PENDING':
                api.abort(400, f'Cannot reject reservation with status: {reservation.status}')
            
            # Update reservation status (no seat changes)
            reservation.status = 'REJECTED'
            
            # Create notification for the employee
            notification = Notification(
                employee_id=reservation.employee_id,
                ride_id=ride.id,
                message=f'Reservation REJECTED for {ride.origin} → {ride.destination} (Ride #{ride.id}). Please find another ride.',
                is_read=False
            )
            db.session.add(notification)
            
            db.session.commit()

            # Log reservation rejection
            log_action(
                action='RESERVATION_REJECTED',
                employee_id=employee_id,
                details={'reservation_id': reservation.id, 'ride_id': ride.id, 'seats_reserved': reservation.seats_reserved}
            )

            return reservation, 200
            
        except HTTPException:
            # Re-raise HTTP exceptions (403, 404, 400) without modification
            raise
        except Exception as e:
            db.session.rollback()
            api.abort(500, f'Rejection failed: {str(e)}')


@api.route('/<int:id>')
@api.param('id', 'Reservation ID')
class ReservationDetail(Resource):
    @jwt_required()
    @api.doc('delete_reservation', security='Bearer', description='Delete a reservation by ID',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            404: ('Reservation not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
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
