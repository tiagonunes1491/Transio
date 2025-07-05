# backend/tests/unit/test_main_90_percent_coverage.py
"""
Final test to achieve 90%+ coverage for main.py
"""
import pytest
import json
from unittest.mock import patch


class TestMainRetrievalEdgeCases:
    """Test edge cases in secret retrieval to achieve 90%+ coverage"""
    
    def test_retrieve_secret_empty_link_id(self, client):
        """Test defensive check for empty link_id (lines 130-131)"""
        # This is a defensive check that should normally be caught by Flask routing
        # But we can test it by calling the function directly
        from app.main import retrieve_secret_api
        from app.main import app
        
        with app.test_request_context():
            # Call with empty string
            response, status_code = retrieve_secret_api("")
            assert status_code == 404
            data = json.loads(response.get_data())
            assert "Secret ID is required" in data['error']
    
    def test_retrieve_secret_e2ee_delete_failure(self, client):
        """Test E2EE secret retrieval when delete fails (line 179)"""
        import uuid
        from app.models import Secret
        
        link_id = str(uuid.uuid4())
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=b'client_encrypted_data',
            mime_type='text/plain',
            is_e2ee=True,
            e2ee_data={'salt': 'test_salt', 'nonce': 'test_nonce'}
        )
        
        with patch('app.main.retrieve_secret') as mock_retrieve, \
             patch('app.main.delete_secret') as mock_delete:
            
            mock_retrieve.return_value = mock_secret
            mock_delete.return_value = False  # Delete fails
            
            response = client.get(f'/api/share/secret/{link_id}')
            
            assert response.status_code == 200
            data = response.get_json()
            assert 'payload' in data
            assert 'e2ee' in data
            
            # Verify delete was attempted
            mock_delete.assert_called_once_with(link_id)
    
    def test_retrieve_secret_traditional_delete_failure(self, client):
        """Test traditional secret retrieval when delete fails (line 192)"""
        import uuid
        from app.models import Secret
        
        link_id = str(uuid.uuid4())
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
            mock_delete.return_value = False  # Delete fails
            
            response = client.get(f'/api/share/secret/{link_id}')
            
            assert response.status_code == 200
            data = response.get_json()
            assert 'payload' in data
            
            # Verify delete was attempted
            mock_delete.assert_called_once_with(link_id)
    
    def test_retrieve_secret_decryption_failure_path(self, client):
        """Test decryption failure path (lines 204-210)"""
        import uuid
        from app.models import Secret
        
        link_id = str(uuid.uuid4())
        mock_secret = Secret(
            link_id=link_id,
            encrypted_secret=b'corrupted_encrypted_data',
            mime_type='text/plain',
            is_e2ee=False,
            e2ee_data=None
        )
        
        with patch('app.main.retrieve_secret') as mock_retrieve, \
             patch('app.main.decrypt_secret') as mock_decrypt, \
             patch('app.main.delete_secret') as mock_delete:
            
            mock_retrieve.return_value = mock_secret
            mock_decrypt.return_value = None  # Decryption fails
            mock_delete.return_value = True
            
            response = client.get(f'/api/share/secret/{link_id}')
            
            assert response.status_code == 200
            data = response.get_json()
            assert '_padding' in data  # Should return padded response with _padding key
            
            # Verify secret was deleted due to corruption
            mock_delete.assert_called_once_with(link_id)
    
    def test_retrieve_secret_comprehensive_paths(self, client):
        """Test various other retrieval scenarios to improve coverage"""
        import uuid
        from app.models import Secret
        
        # Test multiple scenarios to hit different code paths
        test_cases = [
            {
                'name': 'json_mime_type',
                'secret': Secret(
                    link_id=str(uuid.uuid4()),
                    encrypted_secret=b'json_data',
                    mime_type='application/json',
                    is_e2ee=False,
                    e2ee_data=None
                ),
                'decrypt_result': '{"key": "value"}'
            },
            {
                'name': 'xml_mime_type',
                'secret': Secret(
                    link_id=str(uuid.uuid4()),
                    encrypted_secret=b'xml_data',
                    mime_type='application/xml',
                    is_e2ee=False,
                    e2ee_data=None
                ),
                'decrypt_result': '<root>data</root>'
            }
        ]
        
        for case in test_cases:
            with patch('app.main.retrieve_secret') as mock_retrieve, \
                 patch('app.main.decrypt_secret') as mock_decrypt, \
                 patch('app.main.delete_secret') as mock_delete:
                
                mock_retrieve.return_value = case['secret']
                mock_decrypt.return_value = case['decrypt_result']
                mock_delete.return_value = True
                
                response = client.get(f'/api/share/secret/{case["secret"].link_id}')
                
                assert response.status_code == 200
                data = response.get_json()
                assert 'payload' in data
                assert data['mime'] == case['secret'].mime_type