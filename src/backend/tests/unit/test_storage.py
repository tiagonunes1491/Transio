# backend/tests/test_storage.py
import pytest
import uuid
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock

from app.storage import (
    generate_unique_link_id,
    store_encrypted_secret,
    retrieve_secret,
    delete_secret,
    retrieve_and_delete_secret
)
from app.models import Secret


class TestGenerateUniqueLinkId:
    """Test cases for the generate_unique_link_id function."""
    
    def test_generate_unique_link_id_format(self):
        """Test that generated link ID is a valid UUID string."""
        link_id = generate_unique_link_id()
        
        assert isinstance(link_id, str)
        # Should be able to parse as UUID
        parsed_uuid = uuid.UUID(link_id)
        assert str(parsed_uuid) == link_id
    
    def test_generate_unique_link_id_uniqueness(self):
        """Test that multiple calls generate unique IDs."""
        ids = [generate_unique_link_id() for _ in range(100)]
        
        # All IDs should be unique
        assert len(set(ids)) == 100


class TestStoreEncryptedSecret:
    """Test cases for the store_encrypted_secret function."""
    
    def test_store_encrypted_secret_success(self, mock_cosmos_container):
        """Test successful storage of encrypted secret."""
        encrypted_data = b"encrypted_test_data"
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = store_encrypted_secret(encrypted_data)
        
        assert result is not None
        assert isinstance(result, str)
        
        # Verify it was stored in mock container
        assert mock_cosmos_container.create_item.called
    
    def test_store_encrypted_secret_invalid_type(self):
        """Test that non-bytes input raises TypeError."""
        with pytest.raises(TypeError, match="Encrypted secret data must be bytes"):
            store_encrypted_secret("not_bytes")
        
        with pytest.raises(TypeError, match="Encrypted secret data must be bytes"):
            store_encrypted_secret(123)
    
    def test_store_encrypted_secret_database_error(self, mock_cosmos_container):
        """Test handling of database errors during storage."""
        mock_cosmos_container.create_item.side_effect = Exception("Cosmos DB error")
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = store_encrypted_secret(b"test_data")
        
        assert result is None


class TestRetrieveAndDeleteSecret:
    """Test cases for the retrieve_and_delete_secret function."""
    
    def test_retrieve_and_delete_secret_success(self, mock_cosmos_container):
        """Test successful retrieval and deletion of secret."""
        # First store a secret
        encrypted_data = b"test_encrypted_data"
        link_id = "test-link-id"
        
        from app.models import Secret
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=encrypted_data,
            is_e2ee=False,
            mime_type="text/plain"
        )
        
        # Override the side_effect to return our mock data
        mock_cosmos_container.read_item.side_effect = None
        mock_cosmos_container.read_item.return_value = mock_secret.to_dict()
        
        # Override delete_item side_effect 
        mock_cosmos_container.delete_item.side_effect = None
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = retrieve_and_delete_secret(link_id)
        
        assert result is not None
        assert result.encrypted_secret == encrypted_data
        
        # Verify it was deleted from mock container for non-E2EE secrets
        assert mock_cosmos_container.delete_item.called
    
    def test_retrieve_and_delete_secret_not_found(self, mock_cosmos_container):
        """Test retrieval of non-existent secret returns None."""
        from azure.cosmos.exceptions import CosmosResourceNotFoundError
        non_existent_id = str(uuid.uuid4())
        
        mock_cosmos_container.read_item.side_effect = CosmosResourceNotFoundError()
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = retrieve_and_delete_secret(non_existent_id)
        
        assert result is None
    
    def test_retrieve_and_delete_secret_invalid_input(self, mock_cosmos_container):
        """Test retrieval with invalid input returns None."""
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            assert retrieve_and_delete_secret("") is None
            assert retrieve_and_delete_secret(None) is None
            assert retrieve_and_delete_secret(123) is None
    
    def test_retrieve_and_delete_secret_database_error(self, mock_cosmos_container):
        """Test handling of database errors during retrieval."""
        mock_cosmos_container.read_item.side_effect = Exception("Cosmos DB error")
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = retrieve_and_delete_secret("test_id")
        
        assert result is None


class TestRetrieveSecret:
    """Test cases for the retrieve_secret function."""
    
    def test_retrieve_secret_success(self, mock_cosmos_container):
        """Test successful retrieval of secret without deletion."""
        encrypted_data = b"test_encrypted_data"
        link_id = "test-link-id"
        
        # Mock the return value for read_item
        from app.models import Secret
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=encrypted_data,
            is_e2ee=False,
            mime_type="text/plain"
        )
        
        # Override the side_effect to return our mock data
        mock_cosmos_container.read_item.side_effect = None
        mock_cosmos_container.read_item.return_value = mock_secret.to_dict()
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = retrieve_secret(link_id)
        
        assert result is not None
        assert result.encrypted_secret == encrypted_data
        assert result.link_id == link_id
    
    def test_retrieve_secret_not_found(self, mock_cosmos_container):
        """Test retrieval of non-existent secret returns None."""
        from azure.cosmos.exceptions import CosmosResourceNotFoundError
        non_existent_id = str(uuid.uuid4())
        
        mock_cosmos_container.read_item.side_effect = CosmosResourceNotFoundError()
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = retrieve_secret(non_existent_id)
        
        assert result is None
    
    def test_retrieve_secret_invalid_input(self, mock_cosmos_container):
        """Test retrieval with invalid input returns None."""
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            assert retrieve_secret("") is None
            assert retrieve_secret(None) is None
            assert retrieve_secret(123) is None
    
    def test_retrieve_secret_database_error(self, mock_cosmos_container):
        """Test handling of database errors during retrieval."""
        mock_cosmos_container.read_item.side_effect = Exception("Cosmos DB error")
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = retrieve_secret("test_id")
        
        assert result is None


class TestDeleteSecret:
    """Test cases for the delete_secret function."""
    
    def test_delete_secret_success(self, mock_cosmos_container):
        """Test successful deletion of secret."""
        test_id = str(uuid.uuid4())
        
        # Override delete_item side_effect 
        mock_cosmos_container.delete_item.side_effect = None
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = delete_secret(test_id)
        
        assert result is True
        assert mock_cosmos_container.delete_item.called
    
    def test_delete_secret_not_found(self, mock_cosmos_container):
        """Test deletion of non-existent secret returns False."""
        from azure.cosmos.exceptions import CosmosResourceNotFoundError
        non_existent_id = str(uuid.uuid4())
        
        mock_cosmos_container.delete_item.side_effect = CosmosResourceNotFoundError()
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = delete_secret(non_existent_id)
        
        assert result is False
    
    def test_delete_secret_invalid_input(self, mock_cosmos_container):
        """Test deletion with invalid input returns False."""
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            assert delete_secret("") is False
            assert delete_secret(None) is False
            assert delete_secret(123) is False
    
    def test_delete_secret_database_error(self, mock_cosmos_container):
        """Test handling of database errors during deletion."""
        mock_cosmos_container.delete_item.side_effect = Exception("Cosmos DB error")
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            result = delete_secret("test_id")
        
        assert result is False


class TestStorageIntegration:
    """Integration tests for storage functions."""
    
    def test_store_retrieve_delete_flow(self, mock_cosmos_container):
        """Test complete flow: store, retrieve, delete."""
        encrypted_data = b"integration_test_data"
        
        # Override create_item side_effect 
        mock_cosmos_container.create_item.side_effect = None
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            # Store
            link_id = store_encrypted_secret(encrypted_data)
            assert link_id is not None
            
            # Mock retrieve response
            from app.models import Secret
            mock_secret = Secret(
                link_id=link_id,
                encrypted_secret=encrypted_data,
                is_e2ee=False,
                mime_type="text/plain"
            )
            
            # Override read_item side_effect 
            mock_cosmos_container.read_item.side_effect = None
            mock_cosmos_container.read_item.return_value = mock_secret.to_dict()
            
            # Retrieve (without deletion)
            retrieved_secret = retrieve_secret(link_id)
            assert retrieved_secret is not None
            assert retrieved_secret.encrypted_secret == encrypted_data
            
            # Override delete_item side_effect 
            mock_cosmos_container.delete_item.side_effect = None
            
            # Retrieve and delete
            retrieved_data = retrieve_and_delete_secret(link_id)
            assert retrieved_data is not None
            assert retrieved_data.encrypted_secret == encrypted_data
            
            # Verify deletion was called
            assert mock_cosmos_container.delete_item.called
    
    def test_multiple_secrets_isolation(self, mock_cosmos_container):
        """Test that multiple secrets are stored and retrieved independently."""
        secrets_data = [
            b"secret_1",
            b"secret_2", 
            b"secret_3"
        ]
        
        # Override create_item side_effect 
        mock_cosmos_container.create_item.side_effect = None
        
        with patch('app.storage.get_container', return_value=mock_cosmos_container):
            # Store all secrets
            link_ids = []
            for data in secrets_data:
                link_id = store_encrypted_secret(data)
                link_ids.append(link_id)
            
            # Mock retrieve responses
            from app.models import Secret
            mock_secrets = []
            for i, (link_id, data) in enumerate(zip(link_ids, secrets_data)):
                mock_secret = Secret(
                    link_id=link_id,
                    encrypted_secret=data,
                    is_e2ee=False,
                    mime_type="text/plain"
                )
                mock_secrets.append(mock_secret)
            
            # Test retrieving specific secret
            mock_cosmos_container.read_item.side_effect = None
            mock_cosmos_container.read_item.return_value = mock_secrets[1].to_dict()
            
            # Override delete_item side_effect 
            mock_cosmos_container.delete_item.side_effect = None
            
            retrieved = retrieve_and_delete_secret(link_ids[1])
            assert retrieved is not None
            assert retrieved.encrypted_secret == secrets_data[1]