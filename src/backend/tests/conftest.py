# backend/tests/conftest.py
import pytest
import os
import sys
from unittest.mock import patch, MagicMock
from cryptography.fernet import Fernet

# Add the parent directory to the Python path so we can import backend as a package
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
parent_dir = os.path.dirname(backend_dir)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

# Set up test environment variables before importing the app
# Generate two keys for MultiFernet testing
current_key = Fernet.generate_key().decode()
previous_key = Fernet.generate_key().decode()

os.environ['MASTER_ENCRYPTION_KEY'] = current_key
os.environ['MASTER_ENCRYPTION_KEY_PREVIOUS'] = previous_key
os.environ['FLASK_DEBUG'] = 'False'
os.environ['MAX_SECRET_LENGTH_KB'] = '100'
os.environ['SECRET_EXPIRY_MINUTES'] = '60'
os.environ['COSMOS_ENDPOINT'] = 'https://localhost:8081'
os.environ['COSMOS_KEY'] = 'C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=='
os.environ['COSMOS_DATABASE_NAME'] = 'TestTransio'
os.environ['COSMOS_CONTAINER_NAME'] = 'test_secrets'


@pytest.fixture
def mock_cosmos_container():
    """Mock Cosmos DB container for testing."""
    container = MagicMock()
    
    # Mock storage for in-memory testing
    _storage = {}
    
    def mock_create_item(body):
        _storage[body['id']] = body
        return body
    
    def mock_read_item(item, partition_key):
        if item in _storage:
            return _storage[item]
        from azure.cosmos.exceptions import CosmosResourceNotFoundError
        raise CosmosResourceNotFoundError(message=f"Item {item} not found")
    
    def mock_delete_item(item, partition_key):
        if item in _storage:
            del _storage[item]
        else:
            from azure.cosmos.exceptions import CosmosResourceNotFoundError
            raise CosmosResourceNotFoundError(message=f"Item {item} not found")
    
    def mock_query_items(query, enable_cross_partition_query=False):
        # Simple query implementation for testing
        return list(_storage.values())
    
    container.create_item = MagicMock(side_effect=mock_create_item)
    container.read_item = MagicMock(side_effect=mock_read_item)
    container.delete_item = MagicMock(side_effect=mock_delete_item)
    container.query_items = MagicMock(side_effect=mock_query_items)
    
    return container


@pytest.fixture
def app(mock_cosmos_container):
    """Create a test Flask application."""
    from flask import Flask
    from flask_cors import CORS
    
    app = Flask(__name__)
    CORS(app)
    
    # Configure for testing
    app.config['TESTING'] = True
    app.config['WTF_CSRF_ENABLED'] = False
    app.config['MAX_SECRET_LENGTH_BYTES'] = 100 * 1024
    app.config['COSMOS_ENDPOINT'] = 'https://localhost:8081'
    app.config['COSMOS_KEY'] = 'C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=='
    app.config['COSMOS_DATABASE_NAME'] = 'TestTransio'
    app.config['COSMOS_CONTAINER_NAME'] = 'test_secrets'
    
    # Mock the Cosmos DB container
    with patch('backend.app.container', mock_cosmos_container):
        # Create a simple test route that mimics the main functionality
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
            yield app


@pytest.fixture
def client(app):
    """Create a test client for the Flask application."""
    return app.test_client()


@pytest.fixture
def app_context(mock_cosmos_container):
    """Provide application context for tests that need it."""
    from flask import Flask
    
    app = Flask(__name__)
    app.config['TESTING'] = True
    app.config['COSMOS_ENDPOINT'] = 'https://localhost:8081'
    app.config['COSMOS_KEY'] = 'C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=='
    app.config['COSMOS_DATABASE_NAME'] = 'TestTransio'
    app.config['COSMOS_CONTAINER_NAME'] = 'test_secrets'
    
    with patch('backend.app.container', mock_cosmos_container):
        with app.app_context():
            yield app


@pytest.fixture
def sample_secret():
    """Provide a sample secret for testing."""
    return "This is a test secret message"


@pytest.fixture
def single_key_environment():
    """Set up environment with only current key for testing backward compatibility."""
    with patch.dict(os.environ, {
        'MASTER_ENCRYPTION_KEY': Fernet.generate_key().decode()
    }, clear=False):
        # Remove previous key if it exists
        if 'MASTER_ENCRYPTION_KEY_PREVIOUS' in os.environ:
            del os.environ['MASTER_ENCRYPTION_KEY_PREVIOUS']
        yield


@pytest.fixture
def key_rotation_environment():
    """Set up environment with both current and previous keys for testing key rotation."""
    current_key = Fernet.generate_key().decode()
    previous_key = Fernet.generate_key().decode()
    
    with patch.dict(os.environ, {
        'MASTER_ENCRYPTION_KEY': current_key,
        'MASTER_ENCRYPTION_KEY_PREVIOUS': previous_key
    }, clear=False):
        yield {
            'current': current_key,
            'previous': previous_key
        }


@pytest.fixture
def encrypted_secret_bytes():
    """Provide sample encrypted secret bytes for testing."""
    from backend.app.encryption import encrypt_secret
    return encrypt_secret("This is a test secret")


@pytest.fixture
def mock_cosmos_session(mock_cosmos_container):
    """Mock Cosmos DB session for testing storage functions."""
    with patch('backend.app.storage.container', mock_cosmos_container):
        yield mock_cosmos_container