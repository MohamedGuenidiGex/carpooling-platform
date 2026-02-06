from app.extensions import api, configure_error_handlers
from .auth import api as auth_ns
from .admin import api as admin_ns
from .employees import api as employees_ns
from .rides import api as rides_ns
from .reservations import api as reservations_ns
from .notifications import api as notifications_ns


def init_api(app):
    # Configure error handlers for standardized responses
    configure_error_handlers(api)
    
    api.add_namespace(auth_ns, path="/auth")
    api.add_namespace(admin_ns, path="/admin")
    api.add_namespace(employees_ns, path="/employees")
    api.add_namespace(rides_ns, path="/rides")
    api.add_namespace(reservations_ns, path="/reservations")
    api.add_namespace(notifications_ns, path="/notifications")
    api.init_app(app)
