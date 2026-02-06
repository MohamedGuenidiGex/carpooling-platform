"""Test configuration for carpooling platform.

This module provides test-specific configuration to ensure tests
run in an isolated environment with separate database.
"""
import os
import tempfile


class TestConfig:
    """Configuration for testing environment."""
    
    # Flask settings
    TESTING = True
    DEBUG = False
    
    # Use in-memory SQLite for fast tests
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    
    # Disable CSRF for testing
    WTF_CSRF_ENABLED = False
    
    # JWT settings - use a different secret for tests
    JWT_SECRET_KEY = 'test-secret-key-do-not-use-in-production'
    
    # Speed up password hashing for tests
    BCRYPT_LOG_ROUNDS = 4
    
    # Disable SQLALCHEMY_TRACK_MODIFICATIONS to avoid warning
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Test-specific settings
    PRESERVE_CONTEXT_ON_EXCEPTION = False


class TestFileDBConfig(TestConfig):
    """Alternative config using file-based SQLite for debugging."""
    
    # Create temp file for database
    db_fd, db_path = tempfile.mkstemp(suffix='.db', prefix='test_carpooling_')
    os.close(db_fd)
    
    SQLALCHEMY_DATABASE_URI = f'sqlite:///{db_path}'
