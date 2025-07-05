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
        with patch('app.main.store_encrypted_secret') as mock_store:
            mock_store.return_value = 'test-uuid-123'
            
            response = client.post('/api/share', json={
                'payload': 'Test secret message',
                'mime': 'text/plain'
            })
            
            assert response.status_code == 201
            data = response.get_json()
            assert data['link_id'] == 'test-uuid-123'
            assert data['e2ee'] is False
            assert data['mime'] == 'text/plain'
    
    def test_share_secret_api_e2ee(self, client):
        """Test E2EE secret sharing through API"""
        with patch('app.main.store_encrypted_secret') as mock_store:
            mock_store.return_value = 'test-e2ee-uuid'
            
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
            assert data['link_id'] == 'test-e2ee-uuid'
            assert data['e2ee'] is True
    
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
        assert response.status_code == 400
    
    def test_retrieve_secret_api_success(self, client):
        """Test successful secret retrieval"""
        from app.models import Secret
        
        link_id = str(uuid.uuid4())
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=b'encrypted_test_data',
            mime_type='text/plain'
        )
        
        with patch('app.main.retrieve_secret') as mock_retrieve, \
             patch('app.main.decrypt_secret') as mock_decrypt, \
             patch('app.main.delete_secret') as mock_delete:
            
            mock_retrieve.return_value = mock_secret
            mock_decrypt.return_value = 'Test secret'
            mock_delete.return_value = True
            
            response = client.get(f'/api/share/{link_id}')
            assert response.status_code == 200
            data = response.get_json()
            assert 'payload' in data
    
    def test_retrieve_secret_api_e2ee(self, client):
        """Test E2EE secret retrieval"""
        from app.models import Secret
        
        link_id = str(uuid.uuid4())
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=b'client_encrypted_payload',
            mime_type='text/plain',
            is_e2ee=True,
            e2ee_data={'salt': 'test_salt', 'nonce': 'test_nonce'}
        )
        
        with patch('app.main.retrieve_secret') as mock_retrieve, \
             patch('app.main.delete_secret') as mock_delete:
            
            mock_retrieve.return_value = mock_secret
            mock_delete.return_value = True
            
            response = client.get(f'/api/share/{link_id}')
            assert response.status_code == 200
            data = response.get_json()
            assert 'payload' in data
            assert 'e2ee' in data
            assert data['e2ee']['salt'] == 'test_salt'
    
    def test_retrieve_secret_api_not_found(self, client):
        """Test secret not found"""
        link_id = str(uuid.uuid4())
        
        with patch('app.main.retrieve_secret') as mock_retrieve:
            mock_retrieve.return_value = None
            
            response = client.get(f'/api/share/{link_id}')
            assert response.status_code == 200  # Returns 200 to prevent enumeration
            data = response.get_json()
            assert 'payload' in data  # Dummy data
    
    def test_share_secret_error_handling(self, client):
        """Test error handling in share secret"""
        with patch('app.main.store_encrypted_secret') as mock_store:
            # Test ValueError
            mock_store.side_effect = ValueError("Invalid data")
            response = client.post('/api/share', json={
                'payload': 'test',
                'mime': 'text/plain'
            })
            assert response.status_code == 400
            
            # Test general exception
            mock_store.side_effect = Exception("Storage error")
            response = client.post('/api/share', json={
                'payload': 'test',
                'mime': 'text/plain'
            })
            assert response.status_code == 500
    
    def test_retrieve_secret_error_handling(self, client):
        """Test error handling in retrieve secret"""
        from app.models import Secret
        
        link_id = str(uuid.uuid4())
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=b'corrupted_data',
            mime_type='text/plain'
        )
        
        with patch('app.main.retrieve_secret') as mock_retrieve, \
             patch('app.main.decrypt_secret') as mock_decrypt, \
             patch('app.main.delete_secret') as mock_delete:
            
            mock_retrieve.return_value = mock_secret
            mock_decrypt.return_value = None  # Decryption failure
            mock_delete.return_value = True
            
            response = client.get(f'/api/share/{link_id}')
            assert response.status_code == 200  # Still returns 200
            
            # Verify corrupted secret was deleted
            mock_delete.assert_called_once_with(link_id)