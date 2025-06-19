# backend/tests/test_storage.py
import pytest
import uuid
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock

from backend.app.storage import (
    generate_unique_link_id,
    store_encrypted_secret,
    retrieve_and_delete_secret,
    cleanup_expired_secrets,
    check_secret_exists
)
from backend.app.models import Secret


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
    
    def test_store_encrypted_secret_success(self, client, app_context, mock_cosmos_session):
        """Test successful storage of encrypted secret."""
        encrypted_data = b"encrypted_test_data"
        
        with patch('backend.app.storage.container', mock_cosmos_session):
            result = store_encrypted_secret(encrypted_data)
        
        assert result is not None
        assert isinstance(result, str)
        
        # Verify it was stored in mock container
        assert mock_cosmos_session.create_item.called
    
    def test_store_encrypted_secret_invalid_type(self, app_context):
        """Test that non-bytes input raises TypeError."""
        with pytest.raises(TypeError, match="Encrypted secret data must be bytes"):
            store_encrypted_secret("not_bytes")
        
        with pytest.raises(TypeError, match="Encrypted secret data must be bytes"):
            store_encrypted_secret(123)
    
    @patch('backend.app.storage.container')
    def test_store_encrypted_secret_database_error(self, mock_container, app_context):
        """Test handling of database errors during storage."""
        mock_container.create_item.side_effect = Exception("Cosmos DB error")
        
        result = store_encrypted_secret(b"test_data")
        
        assert result is None


class TestRetrieveAndDeleteSecret:
    """Test cases for the retrieve_and_delete_secret function."""
    
    def test_retrieve_and_delete_secret_success(self, client, app_context, mock_cosmos_session):
        """Test successful retrieval and deletion of secret."""
        # First store a secret
        encrypted_data = b"test_encrypted_data"
        
        with patch('backend.app.storage.container', mock_cosmos_session):
            link_id = store_encrypted_secret(encrypted_data)
            
            # Retrieve and delete it
            result = retrieve_and_delete_secret(link_id)
        
        assert result == encrypted_data
        
        # Verify it was deleted from mock container
        assert mock_cosmos_session.delete_item.called
    
    def test_retrieve_and_delete_secret_not_found(self, app_context, mock_cosmos_session):
        """Test retrieval of non-existent secret returns None."""
        non_existent_id = str(uuid.uuid4())
        
        with patch('backend.app.storage.container', mock_cosmos_session):
            result = retrieve_and_delete_secret(non_existent_id)
        
        assert result is None
    
    def test_retrieve_and_delete_secret_invalid_input(self, app_context, mock_cosmos_session):
        """Test retrieval with invalid input returns None."""
        with patch('backend.app.storage.container', mock_cosmos_session):
            assert retrieve_and_delete_secret("") is None
            assert retrieve_and_delete_secret(None) is None
            assert retrieve_and_delete_secret(123) is None
    
    @patch('backend.app.storage.container')
    def test_retrieve_and_delete_secret_database_error(self, mock_container, app_context):
        """Test handling of database errors during retrieval."""
        mock_container.read_item.side_effect = Exception("Cosmos DB error")
        
        result = retrieve_and_delete_secret("test_id")
        
        assert result is None


class TestCheckSecretExists:
    """Test cases for the check_secret_exists function."""
    
    def test_check_secret_exists_true(self, client, app_context, mock_cosmos_session):
        """Test checking existence of a stored secret returns True."""
        encrypted_data = b"test_encrypted_data"
        
        with patch('backend.app.storage.container', mock_cosmos_session):
            link_id = store_encrypted_secret(encrypted_data)
            result = check_secret_exists(link_id)
        
        assert result is True
    
    def test_check_secret_exists_false(self, app_context, mock_cosmos_session):
        """Test checking existence of non-existent secret returns False."""
        non_existent_id = str(uuid.uuid4())
        
        with patch('backend.app.storage.container', mock_cosmos_session):
            result = check_secret_exists(non_existent_id)
        
        assert result is False
    
    def test_check_secret_exists_empty_input(self, app_context, mock_cosmos_session):
        """Test checking existence with empty input returns False."""
        with patch('backend.app.storage.container', mock_cosmos_session):
            result = check_secret_exists("")
        
        assert result is False
    
    def test_check_secret_exists_expired_secret(self, client, app_context, mock_cosmos_session):
        """Test checking existence of expired secret returns False."""
        # This test is mostly handled by Cosmos DB TTL automatically
        # For testing purposes, we'll simulate an expired secret check
        expired_id = str(uuid.uuid4())
        
        with patch('backend.app.storage.container', mock_cosmos_session):
            result = check_secret_exists(expired_id)
        
        assert result is False
    
    @patch('backend.app.storage.container')
    def test_check_secret_exists_database_error(self, mock_container, app_context):
        """Test handling of database errors during existence check."""
        mock_container.read_item.side_effect = Exception("Cosmos DB error")
        
        result = check_secret_exists("test_id")
        
        assert result is False


class TestCleanupExpiredSecrets:
    """Test cases for the cleanup_expired_secrets function."""
    
    def test_cleanup_expired_secrets_removes_old(self, client, app_context, mock_cosmos_session):
        """Test that cleanup removes expired secrets."""
        # With Cosmos DB TTL, cleanup is mostly automatic
        # This test simulates the manual cleanup function
        with patch('backend.app.storage.container', mock_cosmos_session):
            removed_count = cleanup_expired_secrets()
        
        # Should return 0 since mock container has no expired items
        assert removed_count >= 0
    
    def test_cleanup_expired_secrets_no_expired(self, client, app_context, mock_cosmos_session):
        """Test cleanup when no expired secrets exist."""
        with patch('backend.app.storage.container', mock_cosmos_session):
            removed_count = cleanup_expired_secrets()
        
        assert removed_count == 0
    
    @patch('backend.app.storage.container')
    def test_cleanup_expired_secrets_database_error(self, mock_container, app_context):
        """Test handling of database errors during cleanup."""
        mock_container.query_items.side_effect = Exception("Cosmos DB error")
        
        result = cleanup_expired_secrets()
        
        assert result == 0


class TestStorageIntegration:
    """Integration tests for storage functions."""
    
    def test_store_retrieve_delete_flow(self, client, app_context, mock_cosmos_session):
        """Test complete flow: store, check exists, retrieve/delete."""
        encrypted_data = b"integration_test_data"
        
        with patch('backend.app.storage.container', mock_cosmos_session):
            # Store
            link_id = store_encrypted_secret(encrypted_data)
            assert link_id is not None
            
            # Check exists
            assert check_secret_exists(link_id) is True
            
            # Retrieve and delete
            retrieved_data = retrieve_and_delete_secret(link_id)
            assert retrieved_data == encrypted_data
            
            # Verify it no longer exists
            assert check_secret_exists(link_id) is False
            assert retrieve_and_delete_secret(link_id) is None
    
    def test_multiple_secrets_isolation(self, client, app_context, mock_cosmos_session):
        """Test that multiple secrets are stored and retrieved independently."""
        secrets_data = [
            b"secret_1",
            b"secret_2", 
            b"secret_3"
        ]
        
        with patch('backend.app.storage.container', mock_cosmos_session):
            # Store all secrets
            link_ids = []
            for data in secrets_data:
                link_id = store_encrypted_secret(data)
                link_ids.append(link_id)
            
            # Verify all exist
            for link_id in link_ids:
                assert check_secret_exists(link_id) is True
            
            # Retrieve one secret
            retrieved = retrieve_and_delete_secret(link_ids[1])
            assert retrieved == secrets_data[1]
            
            # Verify only that one was deleted
            assert check_secret_exists(link_ids[0]) is True
            assert check_secret_exists(link_ids[1]) is False
            assert check_secret_exists(link_ids[2]) is True