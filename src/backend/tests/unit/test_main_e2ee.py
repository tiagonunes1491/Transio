# backend/tests/unit/test_main_e2ee.py
"""
Tests for E2EE functionality in main.py
"""
import pytest
import json
import uuid
from unittest.mock import patch, MagicMock


class TestE2EESecretAPI:
    """Test cases for E2EE secret sharing functionality."""
    
    def test_share_e2ee_secret_success(self, client):
        """Test successful E2EE secret sharing."""
        e2ee_data = {
            "payload": "encrypted_client_side_data",
            "mime": "text/plain",
            "e2ee": {
                "salt": "YWJjZGVmZ2hpams",
                "nonce": "bG1ub3BxcnN0dXZ3"
            }
        }
        
        response = client.post('/api/share', 
                              data=json.dumps(e2ee_data),
                              content_type='application/json')
        
        assert response.status_code == 201
        data = json.loads(response.data)
        assert 'link_id' in data
        assert data['e2ee'] is True
        assert data['mime'] == 'text/plain'
        assert data['message'] == 'Secret stored successfully.'
        
        # Verify link_id is a valid UUID
        uuid.UUID(data['link_id'])  # Will raise if invalid
    
    def test_share_e2ee_secret_missing_salt(self, client):
        """Test E2EE request missing required salt field."""
        e2ee_data = {
            "payload": "encrypted_data",
            "e2ee": {
                "nonce": "bG1ub3BxcnN0dXZ3"
                # Missing salt
            }
        }
        
        response = client.post('/api/share',
                              data=json.dumps(e2ee_data),
                              content_type='application/json')
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "Missing 'e2ee.salt' field" in data['error']
    
    def test_share_e2ee_secret_missing_nonce(self, client):
        """Test E2EE request missing required nonce field."""
        e2ee_data = {
            "payload": "encrypted_data",
            "e2ee": {
                "salt": "YWJjZGVmZ2hpams"
                # Missing nonce
            }
        }
        
        response = client.post('/api/share',
                              data=json.dumps(e2ee_data),
                              content_type='application/json')
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "Missing 'e2ee.nonce' field" in data['error']
    
    def test_share_e2ee_secret_invalid_salt_type(self, client):
        """Test E2EE request with non-string salt."""
        e2ee_data = {
            "payload": "encrypted_data",
            "e2ee": {
                "salt": 123,  # Should be string
                "nonce": "bG1ub3BxcnN0dXZ3"
            }
        }
        
        response = client.post('/api/share',
                              data=json.dumps(e2ee_data),
                              content_type='application/json')
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "'e2ee.salt' must be a string" in data['error']
    
    def test_share_e2ee_secret_invalid_nonce_type(self, client):
        """Test E2EE request with non-string nonce."""
        e2ee_data = {
            "payload": "encrypted_data",
            "e2ee": {
                "salt": "YWJjZGVmZ2hpams",
                "nonce": ["array"]  # Should be string
            }
        }
        
        response = client.post('/api/share',
                              data=json.dumps(e2ee_data),
                              content_type='application/json')
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "'e2ee.nonce' must be a string" in data['error']
    
    def test_share_e2ee_secret_invalid_e2ee_structure(self, client):
        """Test E2EE request with invalid e2ee structure."""
        e2ee_data = {
            "payload": "encrypted_data",
            "e2ee": "not_an_object"  # Should be dict
        }
        
        response = client.post('/api/share',
                              data=json.dumps(e2ee_data),
                              content_type='application/json')
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "'e2ee' must be an object" in data['error']
    
    def test_share_secret_invalid_mime_type(self, client):
        """Test request with non-string mime type."""
        secret_data = {
            "payload": "test secret",
            "mime": 123  # Should be string
        }
        
        response = client.post('/api/share',
                              data=json.dumps(secret_data),
                              content_type='application/json')
        
        assert response.status_code == 400
        data = json.loads(response.data)
        assert "'mime' must be a string" in data['error']


class TestSecretRetrievalEdgeCases:
    """Test edge cases for secret retrieval."""
    
    def test_retrieve_secret_with_malformed_link_id(self, client):
        """Test retrieval with non-existent but valid UUID format."""
        # Use valid UUID format but non-existent
        non_existent_uuid = str(uuid.uuid4())
        
        response = client.get(f'/api/share/secret/{non_existent_uuid}')
        # API returns 200 with dummy data to prevent enumeration
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'payload' in data
        assert 'mime' in data
    
    def test_head_request_with_malformed_link_id(self, client):
        """Test HEAD request with malformed link ID."""
        response = client.head('/api/share/secret/invalid-uuid')
        # API returns 200 to prevent enumeration
        assert response.status_code == 200
        assert response.data == b''


class TestErrorHandlingPaths:
    """Test error handling paths in the application."""
    
    @patch('app.main.store_encrypted_secret')
    def test_storage_error_handling(self, mock_store, client):
        """Test handling of storage errors."""
        # Mock storage to raise an exception
        mock_store.side_effect = Exception("Database connection failed")
        
        secret_data = {"payload": "test secret"}
        
        response = client.post('/api/share',
                              data=json.dumps(secret_data),
                              content_type='application/json')
        
        # Should return 500 for storage failure
        assert response.status_code == 500
        data = json.loads(response.data)
        assert "Failed to store secret due to an internal server error" in data['error']