from flask_restx import Api
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager

api = Api(
    title="Gexpertise Smart Carpooling API",
    version="1.0",
    doc="/docs",
)

db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
