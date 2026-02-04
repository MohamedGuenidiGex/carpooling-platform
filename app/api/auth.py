from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import create_access_token

from app.models import Employee

api = Namespace('auth', description='Authentication operations')

dev_token_request = api.model('DevTokenRequest', {
    'employee_id': fields.Integer(required=True, description='Employee ID to generate token for')
})

dev_token_response = api.model('DevTokenResponse', {
    'access_token': fields.String(description='JWT access token'),
    'token_type': fields.String(description='Token type (Bearer)')
})


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
