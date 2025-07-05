# backend/tests/unit/test_init_coverage.py
"""
Comprehensive tests for app/__init__.py to achieve high coverage
"""
import pytest
import os
from unittest.mock import patch, MagicMock, Mock
import sys

# Add the app directory to Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))


class TestCosmosDBInitialization:
    """Test the init_cosmos_db function with various scenarios"""
    
    def test_cosmos_db_init_success_with_key(self):
        """Test successful Cosmos DB initialization with access key"""
        with patch('app.CosmosClient') as mock_cosmos_client:
            mock_app = MagicMock()
            mock_app.config = {
                'COSMOS_ENDPOINT': 'https://test.cosmos.azure.com:443/',
                'COSMOS_KEY': 'test_key',
                'USE_MANAGED_IDENTITY': False,
                'COSMOS_DATABASE_NAME': 'TestDB',
                'COSMOS_CONTAINER_NAME': 'test_container'
            }
            
            # Mock the client and container
            mock_client = MagicMock()
            mock_cosmos_client.return_value = mock_client
            
            mock_database = MagicMock()
            mock_client.get_database_client.return_value = mock_database
            
            mock_container = MagicMock()
            mock_database.get_container_client.return_value = mock_container
            mock_container.read.return_value = {'id': 'test_container', 'defaultTtl': 3600}
            
            from app import init_cosmos_db
            result = init_cosmos_db(mock_app)
            
            assert result is True
            assert hasattr(mock_app, 'cosmos_client')
            assert hasattr(mock_app, 'cosmos_database')
            assert hasattr(mock_app, 'cosmos_container')

    def test_cosmos_db_init_success_with_managed_identity(self):
        """Test successful Cosmos DB initialization with managed identity"""
        with patch('app.CosmosClient') as mock_cosmos_client, \
             patch('app.DefaultAzureCredential') as mock_credential:
            
            mock_app = MagicMock()
            mock_app.config = {
                'COSMOS_ENDPOINT': 'https://test.cosmos.azure.com:443/',
                'USE_MANAGED_IDENTITY': True,
                'COSMOS_DATABASE_NAME': 'TestDB',
                'COSMOS_CONTAINER_NAME': 'test_container'
            }
            
            # Mock environment variable
            with patch.dict(os.environ, {'AZURE_CLIENT_ID': 'test-client-id'}):
                mock_client = MagicMock()
                mock_cosmos_client.return_value = mock_client
                
                mock_database = MagicMock()
                mock_client.get_database_client.return_value = mock_database
                
                mock_container = MagicMock()
                mock_database.get_container_client.return_value = mock_container
                mock_container.read.return_value = {'id': 'test_container'}
                
                from app import init_cosmos_db
                result = init_cosmos_db(mock_app)
                
                assert result is True
                # Verify credential was called with client_id
                mock_credential.assert_called_with(managed_identity_client_id='test-client-id')

    def test_cosmos_db_init_managed_identity_no_client_id(self):
        """Test managed identity without client ID (system-assigned)"""
        with patch('app.CosmosClient') as mock_cosmos_client, \
             patch('app.DefaultAzureCredential') as mock_credential:
            
            mock_app = MagicMock()
            mock_app.config = {
                'COSMOS_ENDPOINT': 'https://test.cosmos.azure.com:443/',
                'USE_MANAGED_IDENTITY': True,
                'COSMOS_DATABASE_NAME': 'TestDB',
                'COSMOS_CONTAINER_NAME': 'test_container'
            }
            
            # Ensure AZURE_CLIENT_ID is not set
            with patch.dict(os.environ, {}, clear=True):
                mock_client = MagicMock()
                mock_cosmos_client.return_value = mock_client
                
                mock_database = MagicMock()
                mock_client.get_database_client.return_value = mock_database
                
                mock_container = MagicMock()
                mock_database.get_container_client.return_value = mock_container
                mock_container.read.return_value = {'id': 'test_container'}
                
                from app import init_cosmos_db
                result = init_cosmos_db(mock_app)
                
                assert result is True
                # Verify credential was called without client_id
                mock_credential.assert_called_with()

    def test_cosmos_db_init_localhost_emulator(self):
        """Test Cosmos DB initialization with localhost emulator"""
        with patch('app.CosmosClient') as mock_cosmos_client:
            mock_app = MagicMock()
            mock_app.config = {
                'COSMOS_ENDPOINT': 'https://localhost:8081',
                'COSMOS_KEY': 'test_key',
                'USE_MANAGED_IDENTITY': False,
                'COSMOS_DATABASE_NAME': 'TestDB',
                'COSMOS_CONTAINER_NAME': 'test_container'
            }
            
            mock_client = MagicMock()
            mock_cosmos_client.return_value = mock_client
            
            mock_database = MagicMock()
            mock_client.get_database_client.return_value = mock_database
            
            mock_container = MagicMock()
            mock_database.get_container_client.return_value = mock_container
            mock_container.read.return_value = {'id': 'test_container'}
            
            from app import init_cosmos_db
            result = init_cosmos_db(mock_app)
            
            assert result is True
            # Verify connection_verify=False was passed for emulator
            mock_cosmos_client.assert_called_with('https://localhost:8081', 'test_key', connection_verify=False)

    def test_cosmos_db_init_cosmosdb_emulator(self):
        """Test Cosmos DB initialization with cosmosdb:8081 emulator"""
        with patch('app.CosmosClient') as mock_cosmos_client:
            mock_app = MagicMock()
            mock_app.config = {
                'COSMOS_ENDPOINT': 'https://cosmosdb:8081',
                'COSMOS_KEY': 'test_key',
                'USE_MANAGED_IDENTITY': False,
                'COSMOS_DATABASE_NAME': 'TestDB',
                'COSMOS_CONTAINER_NAME': 'test_container'
            }
            
            mock_client = MagicMock()
            mock_cosmos_client.return_value = mock_client
            
            mock_database = MagicMock()
            mock_client.get_database_client.return_value = mock_database
            
            mock_container = MagicMock()
            mock_database.get_container_client.return_value = mock_container
            mock_container.read.return_value = {'id': 'test_container'}
            
            from app import init_cosmos_db
            result = init_cosmos_db(mock_app)
            
            assert result is True
            # Verify connection_verify=False was passed for emulator
            mock_cosmos_client.assert_called_with('https://cosmosdb:8081', 'test_key', connection_verify=False)

    def test_cosmos_db_init_no_endpoint(self):
        """Test Cosmos DB initialization failure due to missing endpoint"""
        mock_app = MagicMock()
        mock_app.config = {}  # No endpoint
        
        from app import init_cosmos_db
        result = init_cosmos_db(mock_app)
        
        assert result is False

    def test_cosmos_db_init_no_auth_method(self):
        """Test Cosmos DB initialization failure due to no auth method"""
        mock_app = MagicMock()
        mock_app.config = {
            'COSMOS_ENDPOINT': 'https://test.cosmos.azure.com:443/',
            'USE_MANAGED_IDENTITY': False,
            # No key provided
        }
        
        from app import init_cosmos_db
        result = init_cosmos_db(mock_app)
        
        assert result is False

    def test_cosmos_db_init_connection_failure(self):
        """Test Cosmos DB initialization failure due to connection error"""
        with patch('app.CosmosClient') as mock_cosmos_client:
            mock_app = MagicMock()
            mock_app.config = {
                'COSMOS_ENDPOINT': 'https://test.cosmos.azure.com:443/',
                'COSMOS_KEY': 'test_key',
                'USE_MANAGED_IDENTITY': False,
                'COSMOS_DATABASE_NAME': 'TestDB',
                'COSMOS_CONTAINER_NAME': 'test_container'
            }
            
            # Mock an exception during client creation
            mock_cosmos_client.side_effect = Exception("Connection failed")
            
            from app import init_cosmos_db
            result = init_cosmos_db(mock_app)
            
            assert result is False

    def test_cosmos_db_init_container_read_failure(self):
        """Test Cosmos DB initialization failure due to container read error"""
        with patch('app.CosmosClient') as mock_cosmos_client:
            mock_app = MagicMock()
            mock_app.config = {
                'COSMOS_ENDPOINT': 'https://test.cosmos.azure.com:443/',
                'COSMOS_KEY': 'test_key',
                'USE_MANAGED_IDENTITY': False,
                'COSMOS_DATABASE_NAME': 'TestDB',
                'COSMOS_CONTAINER_NAME': 'test_container'
            }
            
            mock_client = MagicMock()
            mock_cosmos_client.return_value = mock_client
            
            mock_database = MagicMock()
            mock_client.get_database_client.return_value = mock_database
            
            mock_container = MagicMock()
            mock_database.get_container_client.return_value = mock_container
            # Mock container read failure
            mock_container.read.side_effect = Exception("Container not found")
            
            from app import init_cosmos_db
            result = init_cosmos_db(mock_app)
            
            assert result is False


class TestGetCosmosContainer:
    """Test the get_cosmos_container function"""
    
    def test_get_cosmos_container_success(self):
        """Test successful retrieval of cosmos container"""
        with patch('app.current_app') as mock_current_app:
            mock_container = MagicMock()
            mock_current_app.cosmos_container = mock_container
            
            from app import get_cosmos_container
            result = get_cosmos_container()
            
            assert result is mock_container

    def test_get_cosmos_container_not_found(self):
        """Test retrieval when container is not set"""
        with patch('app.current_app') as mock_current_app:
            # Container not set
            del mock_current_app.cosmos_container
            
            from app import get_cosmos_container
            result = get_cosmos_container()
            
            assert result is None