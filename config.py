import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY')
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY')

class DevelopmentConfig(Config):
    SQLALCHEMY_DATABASE_URI = os.environ.get(
        'DATABASE_URL',
        f"sqlite:///{os.path.join(os.getcwd(), 'instance', 'carpooling.db')}"
    )
    DEBUG = True

class ProductionConfig(Config):
    SQLALCHEMY_DATABASE_URI = os.environ.get(
        'DATABASE_URL',
        f"sqlite:///{os.path.join(os.getcwd(), 'instance', 'carpooling.db')}"
    )
    DEBUG = False

class TestingConfig(Config):
    """Configuration for testing environment."""
    # Use in-memory SQLite for fast, isolated tests
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    TESTING = True
    DEBUG = False
    
    # Use a test-specific JWT secret
    JWT_SECRET_KEY = 'test-secret-key-do-not-use-in-production'
    
    # Speed up password hashing for tests
    BCRYPT_LOG_ROUNDS = 4
    
    # Disable CSRF for testing
    WTF_CSRF_ENABLED = False
    
    # Preserve context for test debugging
    PRESERVE_CONTEXT_ON_EXCEPTION = False

config_by_name = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig
}
