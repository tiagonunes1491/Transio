# backend/tests/conftest.py
import pytest
import os
import sys
from unittest.mock import patch
from cryptography.fernet import Fernet

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


@pytest.fixture
def app():
    """Create a test Flask application."""
    from flask import Flask
    from flask_cors import CORS
    
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
    
    # Create a simple test route that mimics the main functionality without importing main.py
    @app.route('/health', methods=['GET'])
    def health_check():
        """Basic health check endpoint for monitoring."""
        from flask import jsonify
        return jsonify({"status": "healthy", "message": "Backend is running."}), 200
    
    @app.route('/api/share', methods=['POST'])
    def share_secret_api():
        """API endpoint to share a new secret."""
        from flask import request, jsonify, current_app
        from backend.app.encryption import encrypt_secret
        from backend.app.storage import store_encrypted_secret
        
        if not request.is_json:
            return jsonify({"error": "Request must be JSON"}), 400

        data = request.get_json()
        secret_text = data.get("secret")

        if not secret_text:
            return jsonify({"error": "Missing 'secret' field in JSON payload"}), 400

        if not isinstance(secret_text, str):
            return jsonify({"error": "'secret' must be a string"}), 400

        # Basic input validation: length check
        if len(secret_text.encode('utf-8')) > current_app.config['MAX_SECRET_LENGTH_BYTES']:
            return jsonify({"error": f"Secret exceeds maximum length of {current_app.config['MAX_SECRET_LENGTH_BYTES'] // 1024}KB"}), 413

        try:
            encrypted_data = encrypt_secret(secret_text)
            link_id = store_encrypted_secret(encrypted_data)
            current_app.logger.info(f"Secret stored successfully with link_id: {link_id}")
            return jsonify({"link_id": link_id, "message": "Secret stored. Use this ID to create your access link."}), 201
        except ValueError as ve:
             current_app.logger.warning(f"ValueError during secret sharing: {ve}")
             return jsonify({"error": "Invalid input provided."}), 400
        except TypeError as te:
             current_app.logger.warning(f"TypeError during secret sharing: {te}")
             return jsonify({"error": "Invalid input type provided."}), 400
        except Exception as e:
            current_app.logger.error(f"Error sharing secret: {e}", exc_info=True)
            return jsonify({"error": "Failed to store secret due to an internal server error."}), 500
    
    @app.route('/api/share/secret/<link_id>', methods=['GET', 'HEAD'])
    def retrieve_secret_api(link_id):
        """API endpoint to retrieve (and delete) a secret."""
        from flask import request, jsonify, current_app
        from backend.app.storage import retrieve_and_delete_secret, check_secret_exists
        from backend.app.encryption import decrypt_secret
        
        if not link_id:
            current_app.logger.warning("Attempt to retrieve secret with empty link_id.")
            return jsonify({"error": "Secret ID is required"}), 404
            
        if request.method == "HEAD":
            exists = check_secret_exists(link_id)
            if exists:
                return "", 200
            else:
                return "", 404

        encrypted_data = retrieve_and_delete_secret(link_id)

        if encrypted_data:
            decrypted_secret = decrypt_secret(encrypted_data)
            if decrypted_secret is not None:
                current_app.logger.info(f"Secret {link_id} retrieved and returned as JSON.")
                return jsonify({"secret": decrypted_secret}), 200
            else:
                current_app.logger.error(f"Failed to decrypt secret for link_id: {link_id}.")
                return jsonify({"error": "Could not decrypt the secret. It may be corrupted or the link is invalid."}), 500
        else:
            current_app.logger.info(f"Secret {link_id} not found for retrieval.")
            return jsonify({"error": "Secret not found. It may have been already viewed, expired, or the link is invalid."}), 404
    
    with app.app_context():
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
    from flask import Flask
    
    app = Flask(__name__)
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    
    from backend.app import db
    db.init_app(app)
    
    from backend.app import models
    
    with app.app_context():
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