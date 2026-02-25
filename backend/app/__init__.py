import os

from flask import Flask
from flask_cors import CORS

from config import config_by_name
from .extensions import db, jwt, migrate, socketio
from .api import init_api

def create_app(config_name):
    os.makedirs(os.path.join(os.getcwd(), 'instance'), exist_ok=True)
    app = Flask(__name__)
    CORS(app, origins="*")  # Enable CORS for all domains to support Flutter Web
    app.config.from_object(config_by_name[config_name])

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    socketio.init_app(app)
    
    # Register global error handlers for standardized responses
    from .utils.error_handlers import register_error_handlers
    register_error_handlers(app)
    
    from . import models as _models  # noqa: F401
    init_api(app)
    
    # Register real-time event handlers
    from .realtime_events import register_socket_handlers
    register_socket_handlers(socketio)

    from .utils.seed import seed_demo_data
    # with app.app_context():
    #     # Create tables if they don't exist (for first run)
    #     db.create_all()
    #     # NOTE: Auto-seeding disabled - use reset_db.py to seed test users manually
    #     # seed_demo_data()

    return app
