# backend/tests/unit/test_app_init_coverage.py
"""
Test app/__init__.py for coverage improvement
"""
import pytest
import os
from unittest.mock import patch, MagicMock


class TestAppInitialization:
    """Test app initialization functions"""
    
    def test_init_cosmos_db_with_key(self):
        """Test Cosmos DB initialization with key authentication"""
        from app import init_cosmos_db
        
        mock_app = MagicMock()
        mock_app.config = {
            'COSMOS_ENDPOINT': 'https://test.documents.azure.com:443/',
            'COSMOS_KEY': 'test_key',
            'USE_MANAGED_IDENTITY': False,
            'COSMOS_DATABASE_NAME': 'TestDB',
            'COSMOS_CONTAINER_NAME': 'test_container'
        }
        
        with patch('app.CosmosClient') as mock_client:
            mock_client_instance = MagicMock()
            mock_client.return_value = mock_client_instance
            
            mock_database = MagicMock()
            mock_client_instance.get_database_client.return_value = mock_database
            
            mock_container = MagicMock()
            mock_database.get_container_client.return_value = mock_container
            mock_container.read.return_value = {'id': 'test_container', 'defaultTtl': 3600}
            
            result = init_cosmos_db(mock_app)
            
            assert result is True
            assert hasattr(mock_app, 'cosmos_client')
            assert hasattr(mock_app, 'cosmos_database')
            assert hasattr(mock_app, 'cosmos_container')
    
    def test_init_cosmos_db_with_managed_identity(self):
        """Test Cosmos DB initialization with managed identity"""
        from app import init_cosmos_db
        
        mock_app = MagicMock()
        mock_app.config = {
            'COSMOS_ENDPOINT': 'https://test.documents.azure.com:443/',
            'USE_MANAGED_IDENTITY': True,
            'COSMOS_DATABASE_NAME': 'TestDB',
            'COSMOS_CONTAINER_NAME': 'test_container'
        }
        
        with patch('app.CosmosClient') as mock_client, \
             patch('app.DefaultAzureCredential') as mock_credential, \
             patch.dict(os.environ, {'AZURE_CLIENT_ID': 'test-client-id'}):
            
            mock_client_instance = MagicMock()
            mock_client.return_value = mock_client_instance
            
            mock_database = MagicMock()
            mock_client_instance.get_database_client.return_value = mock_database
            
            mock_container = MagicMock()
            mock_database.get_container_client.return_value = mock_container
            mock_container.read.return_value = {'id': 'test_container'}
            
            result = init_cosmos_db(mock_app)
            
            assert result is True
            mock_credential.assert_called_with(managed_identity_client_id='test-client-id')
    
    def test_init_cosmos_db_emulator(self):
        """Test Cosmos DB initialization with emulator"""
        from app import init_cosmos_db
        
        mock_app = MagicMock()
        mock_app.config = {
            'COSMOS_ENDPOINT': 'https://localhost:8081',
            'COSMOS_KEY': 'test_key',
            'USE_MANAGED_IDENTITY': False,
            'COSMOS_DATABASE_NAME': 'TestDB',
            'COSMOS_CONTAINER_NAME': 'test_container'
        }
        
        with patch('app.CosmosClient') as mock_client:
            mock_client_instance = MagicMock()
            mock_client.return_value = mock_client_instance
            
            mock_database = MagicMock()
            mock_client_instance.get_database_client.return_value = mock_database
            
            mock_container = MagicMock()
            mock_database.get_container_client.return_value = mock_container
            mock_container.read.return_value = {'id': 'test_container'}
            
            result = init_cosmos_db(mock_app)
            
            assert result is True
            # Verify SSL verification was disabled for emulator
            mock_client.assert_called_with('https://localhost:8081', 'test_key', connection_verify=False)
    
    def test_init_cosmos_db_no_endpoint(self):
        """Test Cosmos DB initialization failure - no endpoint"""
        from app import init_cosmos_db
        
        mock_app = MagicMock()
        mock_app.config = {}
        
        result = init_cosmos_db(mock_app)
        assert result is False
    
    def test_init_cosmos_db_no_auth(self):
        """Test Cosmos DB initialization failure - no auth method"""
        from app import init_cosmos_db
        
        mock_app = MagicMock()
        mock_app.config = {
            'COSMOS_ENDPOINT': 'https://test.documents.azure.com:443/',
            'USE_MANAGED_IDENTITY': False
        }
        
        result = init_cosmos_db(mock_app)
        assert result is False
    
    def test_init_cosmos_db_connection_error(self):
        """Test Cosmos DB initialization failure - connection error"""
        from app import init_cosmos_db
        
        mock_app = MagicMock()
        mock_app.config = {
            'COSMOS_ENDPOINT': 'https://test.documents.azure.com:443/',
            'COSMOS_KEY': 'test_key',
            'USE_MANAGED_IDENTITY': False,
            'COSMOS_DATABASE_NAME': 'TestDB',
            'COSMOS_CONTAINER_NAME': 'test_container'
        }
        
        with patch('app.CosmosClient') as mock_client:
            mock_client.side_effect = Exception("Connection failed")
            
            result = init_cosmos_db(mock_app)
            assert result is False
    
    def test_get_cosmos_container_function_exists(self):
        """Test that get_cosmos_container function exists"""
        from app import get_cosmos_container
        
        # Just verify the function exists and is callable
        assert callable(get_cosmos_container)