# backend/tests/unit/test_main_api_coverage.py
"""
Test main.py API routes for coverage improvement
"""
import pytest
import json
import uuid
from unittest.mock import patch, MagicMock


class TestMainAPIRoutes:
    """Test main.py API routes for coverage"""
    
    def test_health_endpoint(self, client):
        """Test health check endpoint"""
        response = client.get('/health')
        assert response.status_code == 200
        data = response.get_json()
        assert data['status'] == 'healthy'
    
    def test_share_secret_api_success(self, client):
        """Test successful secret sharing through API"""
        response = client.post('/api/share', json={
            'payload': 'Test secret message',
            'mime': 'text/plain'
        })
        
        assert response.status_code == 201
        data = response.get_json()
        # Verify it's a valid UUID format
        uuid.UUID(data['link_id'])  # This will raise ValueError if not valid UUID
        assert data['e2ee'] is False
        assert data['mime'] == 'text/plain'
        assert data['message'] == 'Secret stored successfully.'
    
    def test_share_secret_api_e2ee(self, client):
        """Test E2EE secret sharing through API"""
        response = client.post('/api/share', json={
            'payload': 'client_encrypted_data', 
            'e2ee': {
                'salt': 'client_salt',
                'nonce': 'client_nonce'
            },
            'mime': 'text/plain'
        })
        
        assert response.status_code == 201
        data = response.get_json()
        # Verify it's a valid UUID format
        uuid.UUID(data['link_id'])  # This will raise ValueError if not valid UUID
        assert data['e2ee'] is True
        assert data['mime'] == 'text/plain'
        assert data['message'] == 'Secret stored successfully.'
    
    def test_share_secret_api_missing_data(self, client):
        """Test API with missing data"""
        # Missing payload
        response = client.post('/api/share', json={
            'mime': 'text/plain'
        })
        assert response.status_code == 400
        
        # Empty JSON
        response = client.post('/api/share', json={})
        assert response.status_code == 400
    
    def test_share_secret_api_too_long(self, client):
        """Test API with secret that's too long"""
        long_secret = 'x' * (100 * 1024 + 1)
        response = client.post('/api/share', json={
            'payload': long_secret,
            'mime': 'text/plain'
        })
        assert response.status_code == 413  # Request Entity Too Large
    
    def test_retrieve_secret_api_success(self, client):
        """Test successful secret retrieval"""
        from app.models import Secret
        
        link_id = str(uuid.uuid4())
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=b'encrypted_test_data',
            mime_type='text/plain'
        )
        
        with patch('app.storage.retrieve_secret') as mock_retrieve, \
             patch('app.encryption.decrypt_secret') as mock_decrypt, \
             patch('app.storage.delete_secret') as mock_delete:
            
            mock_retrieve.return_value = mock_secret
            mock_decrypt.return_value = 'Test secret'
            mock_delete.return_value = True
            
            response = client.get(f'/api/share/secret/{link_id}')
            assert response.status_code == 200
            data = response.get_json()
            assert 'payload' in data
    
    def test_retrieve_secret_api_e2ee(self, client):
        """Test E2EE secret retrieval with actual storage and retrieval"""
        # First store an E2EE secret
        store_response = client.post('/api/share', json={
            'payload': 'client_encrypted_payload', 
            'e2ee': {
                'salt': 'test_salt',
                'nonce': 'test_nonce'
            },
            'mime': 'text/plain'
        })
        
        assert store_response.status_code == 201
        store_data = store_response.get_json()
        link_id = store_data['link_id']
        
        # Now retrieve the secret
        response = client.get(f'/api/share/secret/{link_id}')
        assert response.status_code == 200
        data = response.get_json()
        assert 'payload' in data
        assert 'e2ee' in data
        assert data['e2ee']['salt'] == 'test_salt'
        assert data['e2ee']['nonce'] == 'test_nonce'
    
    def test_retrieve_secret_api_not_found(self, client):
        """Test secret not found"""
        link_id = str(uuid.uuid4())
        
        with patch('app.storage.retrieve_secret') as mock_retrieve:
            mock_retrieve.return_value = None
            
            response = client.get(f'/api/share/secret/{link_id}')
            assert response.status_code == 200  # Returns 200 to prevent enumeration
            data = response.get_json()
            assert 'payload' in data  # Dummy data
    
    def test_share_secret_validation_errors(self, client):
        """Test validation errors in share secret"""
        # Test missing payload
        response = client.post('/api/share', json={
            'mime': 'text/plain'
        })
        assert response.status_code == 400
        
        # Test non-string payload  
        response = client.post('/api/share', json={
            'payload': 123,
            'mime': 'text/plain'
        })
        assert response.status_code == 400
    
    def test_retrieve_secret_not_found_behavior(self, client):
        """Test behavior when secret is not found (anti-enumeration)"""
        # Request a non-existent secret
        fake_link_id = str(uuid.uuid4())
        response = client.get(f'/api/share/secret/{fake_link_id}')
        
        # Should return 200 with dummy data to prevent enumeration
        assert response.status_code == 200
        data = response.get_json()
        assert 'payload' in data
        assert data['payload'] == 'Dummy payload for non-existent secret'