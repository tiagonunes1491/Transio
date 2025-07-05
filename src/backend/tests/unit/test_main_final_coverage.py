# backend/tests/unit/test_main_final_coverage.py
"""
Final tests to achieve 90%+ coverage for main.py
"""
import pytest
import json
from unittest.mock import patch


class TestMainFinalCoverage:
    """Final tests to cover remaining main.py lines"""
    
    def test_share_secret_e2ee_success_path(self, client):
        """Test successful E2EE secret sharing to cover lines 72-73, 90-91"""
        with patch('app.main.store_encrypted_secret') as mock_store:
            mock_store.return_value = 'test-e2ee-uuid'
            
            response = client.post('/api/share', json={
                'payload': 'client_encrypted_data',
                'e2ee': {
                    'salt': 'test_salt',
                    'nonce': 'test_nonce'
                },
                'mime': 'text/plain'
            })
            
            assert response.status_code == 201
            data = response.get_json()
            assert data['link_id'] == 'test-e2ee-uuid'
            assert data['e2ee'] is True
            assert data['mime'] == 'text/plain'
            
            # Verify store_encrypted_secret was called with correct parameters
            mock_store.assert_called_once()
            call_args = mock_store.call_args
            assert call_args[1]['is_e2ee'] is True
            assert call_args[1]['mime_type'] == 'text/plain'
            assert call_args[1]['e2ee_data'] == {'salt': 'test_salt', 'nonce': 'test_nonce'}
    
    def test_share_secret_traditional_success_path(self, client):
        """Test successful traditional secret sharing to cover server-side encryption path"""
        with patch('app.main.store_encrypted_secret') as mock_store, \
             patch('app.main.encrypt_secret') as mock_encrypt:
            
            mock_store.return_value = 'test-traditional-uuid'
            mock_encrypt.return_value = b'server_encrypted_data'
            
            response = client.post('/api/share', json={
                'payload': 'plain_text_secret',
                'mime': 'text/plain'
            })
            
            assert response.status_code == 201
            data = response.get_json()
            assert data['link_id'] == 'test-traditional-uuid'
            assert data['e2ee'] is False
            assert data['mime'] == 'text/plain'
            
            # Verify encrypt_secret was called
            mock_encrypt.assert_called_once_with('plain_text_secret')
            
            # Verify store_encrypted_secret was called with encrypted data
            mock_store.assert_called_once()
            call_args = mock_store.call_args
            assert call_args[0][0] == b'server_encrypted_data'  # encrypted data
            assert call_args[1]['is_e2ee'] is False
    
    def test_share_secret_value_error_exception(self, client):
        """Test ValueError exception handling (lines 116-118)"""
        with patch('app.main.encrypt_secret') as mock_encrypt:
            mock_encrypt.side_effect = ValueError("Invalid encryption data")
            
            response = client.post('/api/share', json={
                'payload': 'test_secret',
                'mime': 'text/plain'
            })
            
            assert response.status_code == 400
            data = response.get_json()
            assert 'error' in data
            assert 'Invalid input provided' in data['error']
    
    def test_share_secret_type_error_exception(self, client):
        """Test TypeError exception handling (lines 116-118)"""
        with patch('app.main.encrypt_secret') as mock_encrypt:
            mock_encrypt.side_effect = TypeError("Type mismatch")
            
            response = client.post('/api/share', json={
                'payload': 'test_secret',
                'mime': 'text/plain'
            })
            
            assert response.status_code == 400
            data = response.get_json()
            assert 'error' in data
            assert 'Invalid input provided' in data['error']
    
    def test_share_secret_general_exception(self, client):
        """Test general exception handling (lines 119-123)"""
        with patch('app.main.encrypt_secret') as mock_encrypt:
            mock_encrypt.side_effect = Exception("Database connection failed")
            
            response = client.post('/api/share', json={
                'payload': 'test_secret',
                'mime': 'text/plain'
            })
            
            assert response.status_code == 500
            data = response.get_json()
            assert 'error' in data
            assert 'Failed to store secret due to an internal server error' in data['error']
    
    def test_retrieve_secret_with_timing_simulation(self, client):
        """Test secret retrieval to cover more of the retrieval logic"""
        import uuid
        from app.models import Secret
        
        link_id = str(uuid.uuid4())
        
        # Test successful traditional retrieval
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=b'encrypted_data',
            mime_type='text/plain',
            is_e2ee=False,
            e2ee_data=None
        )
        
        with patch('app.main.retrieve_secret') as mock_retrieve, \
             patch('app.main.decrypt_secret') as mock_decrypt, \
             patch('app.main.delete_secret') as mock_delete:
            
            mock_retrieve.return_value = mock_secret
            mock_decrypt.return_value = 'decrypted_secret'
            mock_delete.return_value = True
            
            response = client.get(f'/api/share/secret/{link_id}')
            
            assert response.status_code == 200
            data = response.get_json()
            assert 'payload' in data
            
            # Verify all functions were called
            mock_retrieve.assert_called_once_with(link_id)
            mock_decrypt.assert_called_once_with(b'encrypted_data')
            mock_delete.assert_called_once_with(link_id)
    
    def test_retrieve_secret_e2ee_path(self, client):
        """Test E2EE secret retrieval path"""
        import uuid
        from app.models import Secret
        
        link_id = str(uuid.uuid4())
        
        # Test E2EE retrieval
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=b'client_encrypted_data',
            mime_type='application/json',
            is_e2ee=True,
            e2ee_data={'salt': 'salt_value', 'nonce': 'nonce_value'}
        )
        
        with patch('app.main.retrieve_secret') as mock_retrieve, \
             patch('app.main.delete_secret') as mock_delete:
            
            mock_retrieve.return_value = mock_secret
            mock_delete.return_value = True
            
            response = client.get(f'/api/share/secret/{link_id}')
            
            assert response.status_code == 200
            data = response.get_json()
            assert 'payload' in data
            assert 'e2ee' in data
            assert data['e2ee']['salt'] == 'salt_value'
            assert data['e2ee']['nonce'] == 'nonce_value'
            assert data['mime'] == 'application/json'
            
            # Verify secret was deleted
            mock_delete.assert_called_once_with(link_id)