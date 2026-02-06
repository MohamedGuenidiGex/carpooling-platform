"""Centralized error handlers for standardized API error responses."""
import logging
from flask import jsonify
from werkzeug.exceptions import BadRequest, NotFound, Unauthorized, Forbidden, InternalServerError, HTTPException

# Error code mapping
ERROR_CODES = {
    400: 'VALIDATION_ERROR',
    401: 'UNAUTHORIZED',
    403: 'FORBIDDEN',
    404: 'NOT_FOUND',
    500: 'INTERNAL_ERROR'
}

def make_error_response(error_code, message, status_code):
    """Create standardized error response."""
    response = jsonify({
        'error': error_code,
        'message': message
    })
    response.status_code = status_code
    return response

def handle_bad_request(e):
    """Handle 400 validation errors."""
    error_code = 'VALIDATION_ERROR'
    message = str(e.description) if hasattr(e, 'description') else str(e)
    return make_error_response(error_code, message, 400)

def handle_unauthorized(e):
    """Handle 401 unauthorized errors."""
    error_code = 'UNAUTHORIZED'
    message = str(e.description) if hasattr(e, 'description') else 'Authentication required'
    return make_error_response(error_code, message, 401)

def handle_forbidden(e):
    """Handle 403 forbidden errors."""
    error_code = 'FORBIDDEN'
    message = str(e.description) if hasattr(e, 'description') else 'Access denied'
    return make_error_response(error_code, message, 403)

def handle_not_found(e):
    """Handle 404 not found errors."""
    error_code = 'NOT_FOUND'
    message = str(e.description) if hasattr(e, 'description') else 'Resource not found'
    return make_error_response(error_code, message, 404)

def handle_internal_error(e):
    """Handle 500 internal server errors."""
    error_code = 'INTERNAL_ERROR'
    message = str(e.description) if hasattr(e, 'description') else 'Internal server error'
    return make_error_response(error_code, message, 500)

def register_error_handlers(app):
    """Register all error handlers with Flask app."""
    app.register_error_handler(BadRequest, handle_bad_request)
    app.register_error_handler(401, handle_unauthorized)
    app.register_error_handler(Unauthorized, handle_unauthorized)
    app.register_error_handler(403, handle_forbidden)
    app.register_error_handler(Forbidden, handle_forbidden)
    app.register_error_handler(NotFound, handle_not_found)
    app.register_error_handler(404, handle_not_found)
    app.register_error_handler(InternalServerError, handle_internal_error)
    app.register_error_handler(500, handle_internal_error)
    
    # Handle generic exceptions
    @app.errorhandler(Exception)
    def handle_exception(e):
        """Handle any unhandled exceptions."""
        # Log the exception for debugging
        logger = logging.getLogger('carpooling')
        logger.error(f"Unhandled exception: {str(e)}", exc_info=True)
        
        # If it's an HTTP exception we already handle, let it pass through
        if isinstance(e, HTTPException):
            # Re-raise to let Flask-RESTX handle it
            raise e
        
        # Return standardized internal error response
        return make_error_response('INTERNAL_ERROR', 'Unexpected server error', 500)
