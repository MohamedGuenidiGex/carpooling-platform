from app.extensions import api
from .employees import api as employees_ns
from .rides import api as rides_ns
from .reservations import api as reservations_ns
from .notifications import api as notifications_ns


def init_api(app):
    api.add_namespace(employees_ns, path="/employees")
    api.add_namespace(rides_ns, path="/rides")
    api.add_namespace(reservations_ns, path="/reservations")
    api.add_namespace(notifications_ns, path="/notifications")
    api.init_app(app)
