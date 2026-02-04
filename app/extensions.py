from flask_restx import Api
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager

authorizations = {
    'Bearer': {
        'type': 'apiKey',
        'in': 'header',
        'name': 'Authorization',
        'description': 'JWT Authorization header using the Bearer scheme. Example: "Bearer {token}"'
    }
}

api = Api(
    title="Gexpertise Smart Carpooling API",
    version="1.0",
    doc="/docs",
    authorizations=authorizations,
    security='Bearer'
)

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
