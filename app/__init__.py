import os

from flask import Flask

from config import config_by_name
from .extensions import db, jwt, migrate
from .api import init_api

def create_app(config_name):
    os.makedirs(os.path.join(os.getcwd(), 'instance'), exist_ok=True)
    app = Flask(__name__)
    app.config.from_object(config_by_name[config_name])

    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    from . import models as _models  # noqa: F401
    init_api(app)

    from .utils.seed import seed_demo_data
    with app.app_context():
        seed_demo_data()

    return app
