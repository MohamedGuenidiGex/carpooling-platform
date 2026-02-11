from app.extensions import db
from app.models import Employee, Ride

DEMO_EMPLOYEES = [
    {'name': 'Driver One', 'email': 'driver1@gexpertise.com', 'department': 'IT'},
    {'name': 'Employee Two', 'email': 'employee2@gexpertise.com', 'department': 'HR'},
]

DEMO_RIDES = [
    {'origin': 'Tunis', 'destination': 'Ariana', 'available_seats': 3},
    {'origin': 'Ariana', 'destination': 'Tunis', 'available_seats': 2},
]


def _get_or_create_employee(data):
    employee = Employee.query.filter_by(email=data['email']).first()
    if employee:
        # Ensure password is set for existing employees
        if not employee.password_hash:
            employee.set_password(data.get('password', 'password123'))
        return employee
    employee = Employee(
        name=data['name'],
        email=data['email'],
        department=data.get('department', '')
    )
    employee.set_password(data.get('password', 'password123'))
    db.session.add(employee)
    db.session.flush()
    return employee


def seed_demo_data():
    driver = _get_or_create_employee(DEMO_EMPLOYEES[0])
    _get_or_create_employee(DEMO_EMPLOYEES[1])
    db.session.flush()

    existing_rides_count = Ride.query.filter_by(driver_id=driver.id).count()
    if existing_rides_count >= len(DEMO_RIDES):
        db.session.commit()
        return

    for ride_data in DEMO_RIDES:
        ride = Ride(
            driver_id=driver.id,
            departure_time=db.func.now(),
            **ride_data
        )
        db.session.add(ride)
    db.session.commit()
