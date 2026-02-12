from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity

from app.extensions import db
from app.models import Employee
from app.utils.logger import log_action

api = Namespace('auth', description='Authentication operations')

# Swagger models
register_request = api.model('RegisterRequest', {
    'name': fields.String(required=True, description='Employee name'),
    'email': fields.String(required=True, description='Employee email'),
    'password': fields.String(required=True, description='Password'),
    'department': fields.String(required=True, description='Department')
})

register_response = api.model('RegisterResponse', {
    'id': fields.Integer(description='Employee ID'),
    'name': fields.String(description='Employee name'),
    'email': fields.String(description='Employee email'),
    'department': fields.String(description='Employee department'),
    'phone_number': fields.String(description='Phone number'),
    'car_model': fields.String(description='Car model'),
    'car_plate': fields.String(description='Car plate number'),
    'car_color': fields.String(description='Car color'),
    'created_at': fields.DateTime(description='Creation timestamp')
})

login_request = api.model('LoginRequest', {
    'email': fields.String(required=True, description='Employee email'),
    'password': fields.String(required=True, description='Password')
})

login_response = api.model('LoginResponse', {
    'access_token': fields.String(description='JWT access token'),
    'token_type': fields.String(description='Token type (Bearer)'),
    'employee': fields.Nested(register_response)
})

me_response = api.model('MeResponse', {
    'id': fields.Integer(description='Employee ID'),
    'name': fields.String(description='Employee name'),
    'email': fields.String(description='Employee email'),
    'department': fields.String(description='Employee department'),
    'phone_number': fields.String(description='Phone number'),
    'car_model': fields.String(description='Car model'),
    'car_plate': fields.String(description='Car plate number'),
    'car_color': fields.String(description='Car color'),
    'created_at': fields.DateTime(description='Creation timestamp')
})

dev_token_request = api.model('DevTokenRequest', {
    'employee_id': fields.Integer(required=True, description='Employee ID to generate token for')
})

dev_token_response = api.model('DevTokenResponse', {
    'access_token': fields.String(description='JWT access token'),
    'token_type': fields.String(description='Token type (Bearer)')
})

change_password_request = api.model('ChangePasswordRequest', {
    'current_password': fields.String(required=True, description='Current password'),
    'new_password': fields.String(required=True, description='New password')
})

change_password_response = api.model('ChangePasswordResponse', {
    'message': fields.String(description='Success message')
})


@api.route('/register')
class Register(Resource):
    @api.doc('register', description='Create new employee account')
    @api.expect(register_request)
    @api.marshal_with(register_response, code=201)
    def post(self):
        """Register a new employee"""
        data = request.get_json() or {}

        # Validate required fields
        if not data.get('name') or not data.get('email') or not data.get('password') or not data.get('department'):
            api.abort(400, 'name, email, password, and department are required')

        # Check if email already exists
        existing = Employee.query.filter_by(email=data['email']).first()
        if existing:
            api.abort(409, 'Email already registered')

        # Create new employee
        employee = Employee(
            name=data['name'],
            email=data['email'],
            department=data['department']
        )
        employee.set_password(data['password'])

        db.session.add(employee)
        db.session.commit()

        return employee, 201


@api.route('/login')
class Login(Resource):
    @api.doc('login', description='Authenticate employee and get JWT token')
    @api.expect(login_request)
    @api.marshal_with(login_response)
    def post(self):
        """Login and get JWT token"""
        data = request.get_json() or {}

        email = data.get('email')
        password = data.get('password')

        if not email or not password:
            api.abort(400, 'email and password are required')

        employee = Employee.query.filter_by(email=email).first()

        if not employee or not employee.check_password(password):
            api.abort(401, 'Invalid email or password')

        access_token = create_access_token(
            identity=str(employee.id),
            additional_claims={
                'email': employee.email,
                'name': employee.name,
                'department': employee.department
            }
        )

        # Log successful login
        log_action(
            action='USER_LOGIN',
            employee_id=employee.id,
            details={'email': employee.email}
        )

        return {
            'access_token': access_token,
            'token_type': 'Bearer',
            'employee': employee
        }, 200


@api.route('/me')
class Me(Resource):
    @jwt_required()
    @api.doc('get_me', security='Bearer', description='Get current authenticated employee')
    @api.marshal_with(me_response)
    def get(self):
        """Get current authenticated employee"""
        employee_id = int(get_jwt_identity())
        employee = Employee.query.get(employee_id)

        if not employee:
            api.abort(404, 'Employee not found')

        return employee


@api.route('/change-password')
class ChangePassword(Resource):
    @jwt_required()
    @api.doc('change_password', security='Bearer', description='Change employee password')
    @api.expect(change_password_request)
    @api.marshal_with(change_password_response)
    def post(self):
        """Change current employee's password"""
        employee_id = int(get_jwt_identity())
        employee = Employee.query.get(employee_id)

        if not employee:
            api.abort(404, 'Employee not found')

        data = request.get_json() or {}
        current_password = data.get('current_password')
        new_password = data.get('new_password')

        if not current_password or not new_password:
            api.abort(400, 'current_password and new_password are required')

        if not employee.check_password(current_password):
            api.abort(401, 'Current password is incorrect')

        if len(new_password) < 6:
            api.abort(400, 'New password must be at least 6 characters')

        employee.set_password(new_password)
        db.session.commit()

        return {'message': 'Password changed successfully'}, 200


@api.route('/dev-token')
class DevToken(Resource):
    @api.doc('dev_token', description='DEVELOPMENT ONLY: Generate JWT token for an employee')
    @api.expect(dev_token_request)
    @api.marshal_with(dev_token_response)
    def post(self):
        """Generate JWT token for development (will be replaced by Microsoft OAuth)"""
        data = request.get_json() or {}
        employee_id = data.get('employee_id')

        if not employee_id:
            api.abort(400, 'employee_id is required')

        employee = Employee.query.get(employee_id)
        if not employee:
            api.abort(404, 'Employee not found')

        access_token = create_access_token(
            identity=str(employee.id),
            additional_claims={
                'email': employee.email,
                'name': employee.name,
                'department': employee.department
            }
        )

        return {
            'access_token': access_token,
            'token_type': 'Bearer'
        }, 200
