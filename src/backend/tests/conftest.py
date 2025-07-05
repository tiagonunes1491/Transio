# backend/tests/conftest.py
import sys
import os

# Mock Azure dependencies before any other imports
sys.path.insert(0, '/tmp')
import azure_mocks

import pytest
from unittest.mock import patch, MagicMock
from cryptography.fernet import Fernet

# Add the current directory to the Python path so we can import app modules
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

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
        from azure_mocks import CosmosResourceNotFoundError
        raise CosmosResourceNotFoundError(message=f"Item {item} not found")
    
    def mock_delete_item(item, partition_key):
        if item in _storage:
            del _storage[item]
        else:
            from azure_mocks import CosmosResourceNotFoundError
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
    """Create a test Flask application using the actual app structure."""
    # Mock Cosmos DB functions before importing app modules
    with patch('app.get_cosmos_container', return_value=mock_cosmos_container), \
         patch('app.storage.get_cosmos_container', return_value=mock_cosmos_container), \
         patch('app.storage.get_container', return_value=mock_cosmos_container), \
         patch('app.init_cosmos_db', return_value=True):
        
        # Import the actual main app
        from app.main import app as flask_app
        
        # Configure for testing
        flask_app.config['TESTING'] = True
        flask_app.config['WTF_CSRF_ENABLED'] = False
        flask_app.config['MAX_SECRET_LENGTH_BYTES'] = 100 * 1024
        
        with flask_app.app_context():
            yield flask_app


@pytest.fixture
def client(app):
    """Create a test client for the Flask application."""
    return app.test_client()


@pytest.fixture
def app_context(mock_cosmos_container):
    """Provide application context for tests that need it."""
    # Mock Cosmos DB functions before importing app modules
    with patch('app.get_cosmos_container', return_value=mock_cosmos_container), \
         patch('app.storage.get_cosmos_container', return_value=mock_cosmos_container), \
         patch('app.storage.get_container', return_value=mock_cosmos_container), \
         patch('app.init_cosmos_db', return_value=True):
        
        # Import the actual main app
        from app.main import app as flask_app
        
        # Configure for testing
        flask_app.config['TESTING'] = True
        
        with flask_app.app_context():
            yield flask_app


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
    from app.encryption import encrypt_secret
    return encrypt_secret("This is a test secret")


@pytest.fixture
def mock_cosmos_session(mock_cosmos_container):
    """Mock Cosmos DB session for testing storage functions."""
    with patch('app.storage.get_cosmos_container', return_value=mock_cosmos_container), \
         patch('app.storage.get_container', return_value=mock_cosmos_container):
        yield mock_cosmos_container