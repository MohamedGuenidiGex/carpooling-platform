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

def configure_error_handlers(api):
    """Configure Flask-RESTX error handlers for standardized responses."""
    
    @api.errorhandler(Exception)
    def handle_generic_exception(error):
        """Handle generic exceptions."""
        if hasattr(error, 'code'):
            code = error.code
        else:
            code = 500
        
        error_codes = {
            400: 'VALIDATION_ERROR',
            401: 'UNAUTHORIZED',
            403: 'FORBIDDEN',
            404: 'NOT_FOUND',
            500: 'INTERNAL_ERROR'
        }
        
        error_code = error_codes.get(code, 'INTERNAL_ERROR')
        message = str(getattr(error, 'description', str(error)))
        
        return {'error': error_code, 'message': message}, code
    
    @api.errorhandler(ValueError)
    def handle_value_error(error):
        return {'error': 'VALIDATION_ERROR', 'message': str(error)}, 400

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
