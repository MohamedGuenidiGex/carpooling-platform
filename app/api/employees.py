from flask import request
from flask_restx import Namespace, Resource, fields

from app.extensions import db
from app.models import Employee

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
