from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity

from app.extensions import db
from app.models import Employee, Ride, Reservation

api = Namespace('employees', description='Employee operations')

employee_create = api.model('EmployeeCreate', {
    'name': fields.String(required=True, description='Employee name'),
    'email': fields.String(required=True, description='Employee email'),
    'department': fields.String(required=True, description='Employee department')
})

employee_response = api.model('EmployeeResponse', {
    'id': fields.Integer(description='Employee ID'),
    'name': fields.String(description='Employee name'),
    'email': fields.String(description='Employee email'),
    'department': fields.String(description='Employee department'),
    'created_at': fields.DateTime(description='Creation timestamp')
})

# Reuse ride response model for dashboard
ride_response = api.model('RideResponse', {
    'id': fields.Integer(description='Ride ID'),
    'driver_id': fields.Integer(description='Employee ID of the driver'),
    'origin': fields.String(description='Pickup location'),
    'destination': fields.String(description='Drop-off location'),
    'departure_time': fields.DateTime(description='Departure datetime (ISO)'),
    'available_seats': fields.Integer(description='Seats available'),
    'created_at': fields.DateTime(description='Creation timestamp')
})

# Reuse reservation response model for dashboard
reservation_response = api.model('ReservationResponse', {
    'id': fields.Integer(description='Reservation ID'),
    'employee_id': fields.Integer(description='Employee ID of the rider'),
    'ride_id': fields.Integer(description='Ride ID reserved'),
    'seats_reserved': fields.Integer(description='Seats reserved'),
    'status': fields.String(description='Reservation status'),
    'created_at': fields.DateTime(description='Creation timestamp')
})

@api.route('/')
class EmployeeList(Resource):
    @api.doc('list_employees')
    @api.marshal_list_with(employee_response)
    def get(self):
        """List all employees"""
        employees = Employee.query.all()
        return employees

    @api.doc('create_employee')
    @api.expect(employee_create)
    @api.marshal_with(employee_response)
    def post(self):
        """Create a new employee"""
        data = request.get_json() or {}
        if Employee.query.filter_by(email=data.get('email')).first():
            api.abort(400, 'Email already exists')
        employee = Employee(
            name=data['name'],
            email=data['email'],
            department=data['department']
        )
        db.session.add(employee)
        db.session.commit()
        return employee, 201


@api.route('/me/rides')
class MyRides(Resource):
    @jwt_required()
    @api.doc('my_rides', security='Bearer', description='Get all rides where the current employee is the driver')
    @api.marshal_list_with(ride_response)
    def get(self):
        """Get all rides where the current employee is the driver"""
        employee_id = int(get_jwt_identity())
        rides = Ride.query.filter_by(driver_id=employee_id).all()
        return rides


@api.route('/me/reservations')
class MyReservations(Resource):
    @jwt_required()
    @api.doc('my_reservations', security='Bearer', description='Get all reservations made by the current employee')
    @api.marshal_list_with(reservation_response)
    def get(self):
        """Get all reservations made by the current employee"""
        employee_id = int(get_jwt_identity())
        reservations = Reservation.query.filter_by(employee_id=employee_id).all()
        return reservations
