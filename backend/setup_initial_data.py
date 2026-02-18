import os
import sys

# Add the backend directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.extensions import db
from app.models import Employee


def _get_or_create_employee(*, email: str, name: str, password: str, department: str, role: str, status: str):
    employee = Employee.query.filter_by(email=email).first()
    if employee is None:
        employee = Employee(
            name=name,
            email=email,
            department=department,
        )
        db.session.add(employee)

    employee.role = role
    employee.status = status

    if not employee.password_hash:
        employee.set_password(password)

    return employee


def seed_initial_users():
    app = create_app('development')

    with app.app_context():
        _get_or_create_employee(
            email='admin@gexpertise.fr',
            name='Admin',
            password='password123',
            department='IT',
            role='admin',
            status='active',
        )
        _get_or_create_employee(
            email='employee1@gexpertise.fr',
            name='Employee One',
            password='password123',
            department='Operations',
            role='employee',
            status='active',
        )
        _get_or_create_employee(
            email='employee2@gexpertise.fr',
            name='Employee Two',
            password='password123',
            department='HR',
            role='employee',
            status='active',
        )

        db.session.commit()

    print('Database seeded with 1 Admin and 2 Employees')


if __name__ == '__main__':
    seed_initial_users()
