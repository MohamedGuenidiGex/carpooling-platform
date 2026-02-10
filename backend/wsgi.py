from app import create_app

# WSGI entry point for Flask auto-discovery
# Usage: flask run (no environment variables needed)
app = create_app('development')
