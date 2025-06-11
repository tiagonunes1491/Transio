# backend/tests/conftest.py
import pytest
import os
import sys
from unittest.mock import patch
from cryptography.fernet import Fernet
import tempfile

# Add the parent directory to the Python path so we can import backend as a package
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
parent_dir = os.path.dirname(backend_dir)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

# Set up test environment variables before importing the app
os.environ['MASTER_ENCRYPTION_KEY'] = Fernet.generate_key().decode()
os.environ['FLASK_DEBUG'] = 'False'
os.environ['MAX_SECRET_LENGTH_KB'] = '100'
os.environ['SECRET_EXPIRY_MINUTES'] = '60'

# Create a test app that doesn't initialize database on import
def create_test_app():
    """Create a Flask app configured for testing."""
    from flask import Flask
    from flask_cors import CORS
    from backend.config import Config
    
    # Create app without importing main.py which does table creation
    app = Flask(__name__)
    CORS(app)
    
    # Configure for testing
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['WTF_CSRF_ENABLED'] = False
    app.config['MAX_SECRET_LENGTH_BYTES'] = 100 * 1024
    
    # Initialize database
    from backend.app import db
    db.init_app(app)
    
    # Import models to register them
    from backend.app import models
    
    # Register routes
    from backend.app.main import share_secret_api, retrieve_secret_api, health_check
    app.add_url_rule('/api/share', 'share_secret_api', share_secret_api, methods=['POST'])
    app.add_url_rule('/api/share/secret/<link_id>', 'retrieve_secret_api', retrieve_secret_api, methods=['GET', 'HEAD'])
    app.add_url_rule('/health', 'health_check', health_check, methods=['GET'])
    
    return app


@pytest.fixture
def app():
    """Create a test Flask application."""
    app = create_test_app()
    
    with app.app_context():
        from backend.app import db
        db.create_all()
        yield app
        db.drop_all()


@pytest.fixture
def client(app):
    """Create a test client for the Flask application."""
    return app.test_client()


@pytest.fixture
def app_context():
    """Provide application context for tests that need it."""
    app = create_test_app()
    with app.app_context():
        from backend.app import db
        db.create_all()
        yield app
        db.drop_all()


@pytest.fixture
def sample_secret():
    """Provide a sample secret for testing."""
    return "This is a test secret message"


@pytest.fixture
def encrypted_secret_bytes():
    """Provide sample encrypted secret bytes for testing."""
    from backend.app.encryption import encrypt_secret
    return encrypt_secret("This is a test secret")


@pytest.fixture
def mock_db_session():
    """Mock database session for testing storage functions."""
    with patch('backend.app.storage.db.session') as mock_session:
        yield mock_session