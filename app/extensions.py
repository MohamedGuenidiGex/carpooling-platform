from flask import jsonify
from flask_restx import Api
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager
from werkzeug.exceptions import HTTPException

authorizations = {
    'Bearer': {
        'type': 'apiKey',
        'in': 'header',
        'name': 'Authorization',
        'description': 'JWT Authorization header using the Bearer scheme. Example: "Bearer {token}"'
    }
}

# Error code mapping
ERROR_CODES = {
    400: 'VALIDATION_ERROR',
    401: 'UNAUTHORIZED',
    403: 'FORBIDDEN',
    404: 'NOT_FOUND',
    500: 'INTERNAL_ERROR'
}

def configure_error_handlers(api):
    """Configure Flask-RESTX error handlers for standardized responses."""
    
    # Store original error handler
    original_handle_error = api.handle_error
    
    def custom_handle_error(error):
        """Custom error handler that returns standardized format."""
        # Get error code from HTTPException
        if isinstance(error, HTTPException):
            code = error.code
            message = error.description
        elif hasattr(error, 'code'):
            code = error.code
            message = str(getattr(error, 'description', str(error)))
        else:
            # Fall back to original handler for non-HTTP exceptions
            return original_handle_error(error)
        
        # Map to standardized error code
        error_code = ERROR_CODES.get(int(code), 'INTERNAL_ERROR')
        
        # Return standardized response
        return {'error': error_code, 'message': message}, code
    
    # Replace the API's handle_error method
    api.handle_error = custom_handle_error

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

# JWT error handlers for standardized responses
@jwt.unauthorized_loader
def unauthorized_callback(reason):
    """Handle missing JWT token."""
    return jsonify({
        'error': 'UNAUTHORIZED',
        'message': reason
    }), 401

@jwt.invalid_token_loader
def invalid_token_callback(reason):
    """Handle invalid JWT token."""
    return jsonify({
        'error': 'UNAUTHORIZED',
        'message': reason
    }), 401

@jwt.expired_token_loader
def expired_token_callback(jwt_header, jwt_payload):
    """Handle expired JWT token."""
    return jsonify({
        'error': 'UNAUTHORIZED',
        'message': 'Token has expired'
    }), 401
