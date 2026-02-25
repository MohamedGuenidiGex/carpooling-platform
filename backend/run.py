import os
from app import create_app
from app.extensions import socketio

app = create_app(os.getenv('FLASK_ENV') or 'development')

if __name__ == '__main__':
    # Use socketio.run() for WebSocket support in development
    socketio.run(
        app,
        host='0.0.0.0',
        port=5000,
        debug=True,
        allow_unsafe_werkzeug=True
    )
