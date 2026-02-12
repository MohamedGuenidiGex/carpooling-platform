from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity

from app.extensions import db
from app.models import Employee

api = Namespace('users', description='User profile operations')

# Error response model
error_response = api.model('ErrorResponse', {
    'error': fields.String(description='Error code'),
    'message': fields.String(description='Human readable error message')
})

# Profile update model
profile_update = api.model('ProfileUpdate', {
    'phone_number': fields.String(description='Phone number'),
    'car_model': fields.String(description='Car model'),
    'car_plate': fields.String(description='Car plate number'),
    'car_color': fields.String(description='Car color')
})

# User profile response with carpool fields and stats
user_profile_response = api.model('UserProfileResponse', {
    'id': fields.Integer(description='User ID'),
    'name': fields.String(description='User name'),
    'email': fields.String(description='User email'),
    'department': fields.String(description='User department'),
    'phone_number': fields.String(description='Phone number'),
    'car_model': fields.String(description='Car model'),
    'car_plate': fields.String(description='Car plate number'),
    'car_color': fields.String(description='Car color'),
    'rides_offered_count': fields.Integer(description='Number of rides offered'),
    'bookings_count': fields.Integer(description='Number of bookings made'),
    'created_at': fields.DateTime(description='Creation timestamp')
})


@api.route('/me')
class UserProfile(Resource):
    @jwt_required()
    @api.doc('get_user_profile', security='Bearer', description='Get current user profile with stats',
        responses={
            401: ('Unauthorized - JWT required', error_response),
            404: ('User not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.marshal_with(user_profile_response)
    def get(self):
        """Get current user profile with carpool stats"""
        employee_id = int(get_jwt_identity())
        employee = Employee.query.get(employee_id)
        
        if not employee:
            api.abort(404, 'User not found')
        
        # Return employee dict with stats
        return employee.to_dict(include_stats=True)

    @jwt_required()
    @api.doc('update_user_profile', security='Bearer', description='Update current user profile',
        responses={
            400: ('Validation error', error_response),
            401: ('Unauthorized - JWT required', error_response),
            404: ('User not found', error_response),
            500: ('Internal server error', error_response)
        }
    )
    @api.expect(profile_update)
    @api.marshal_with(user_profile_response)
    def patch(self):
        """Update current user profile (phone, car details)"""
        employee_id = int(get_jwt_identity())
        employee = Employee.query.get(employee_id)
        
        if not employee:
            api.abort(404, 'User not found')
        
        data = request.get_json() or {}
        
        # Update allowed fields
        if 'phone_number' in data:
            employee.phone_number = data['phone_number']
        if 'car_model' in data:
            employee.car_model = data['car_model']
        if 'car_plate' in data:
            employee.car_plate = data['car_plate']
        if 'car_color' in data:
            employee.car_color = data['car_color']
        
        db.session.commit()
        
        # Return updated profile with stats
        return employee.to_dict(include_stats=True)
