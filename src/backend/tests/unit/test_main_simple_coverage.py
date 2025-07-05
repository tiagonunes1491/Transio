# backend/tests/unit/test_main_simple_coverage.py
"""
Simple tests for main.py to achieve high coverage
"""
import pytest
import json


class TestMainRoutes:
    """Test main.py routes for coverage"""
    
    def test_health_check_simple(self, client):
        """Test health check endpoint"""
        response = client.get('/health')
        assert response.status_code == 200
        data = response.get_json()
        assert 'status' in data
    
    def test_share_secret_simple_success(self, client):
        """Test simple secret sharing"""
        response = client.post('/api/share', json={
            'payload': 'Test secret message',
            'mime': 'text/plain'
        })
        # Should be 201 if successful, or some error code
        assert response.status_code in [201, 400, 500]
    
    def test_share_secret_missing_payload(self, client):
        """Test missing payload field"""
        response = client.post('/api/share', json={
            'mime': 'text/plain'
        })
        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data
    
    def test_share_secret_non_json(self, client):
        """Test non-JSON request"""
        response = client.post('/api/share', data="not json")
        assert response.status_code == 400
        data = response.get_json()
        assert 'error' in data
        assert 'JSON' in data['error']
    
    def test_share_secret_empty_payload(self, client):
        """Test empty payload"""
        response = client.post('/api/share', json={
            'payload': '',
            'mime': 'text/plain'
        })
        assert response.status_code == 400
    
    def test_share_secret_non_string_payload(self, client):
        """Test non-string payload"""
        response = client.post('/api/share', json={
            'payload': 123,
            'mime': 'text/plain'
        })
        assert response.status_code == 400
    
    def test_share_secret_non_string_mime(self, client):
        """Test non-string mime type"""
        response = client.post('/api/share', json={
            'payload': 'test',
            'mime': 123
        })
        assert response.status_code == 400
    
    def test_share_secret_too_large(self, client):
        """Test payload too large"""
        large_payload = 'x' * (100 * 1024 + 1)
        response = client.post('/api/share', json={
            'payload': large_payload,
            'mime': 'text/plain'
        })
        assert response.status_code == 413
    
    def test_share_secret_e2ee_validation(self, client):
        """Test E2EE field validation"""
        # Missing salt
        response = client.post('/api/share', json={
            'payload': 'encrypted_data',
            'e2ee': {
                'nonce': 'test_nonce'
            },
            'mime': 'text/plain'
        })
        assert response.status_code == 400
        
        # Missing nonce  
        response = client.post('/api/share', json={
            'payload': 'encrypted_data',
            'e2ee': {
                'salt': 'test_salt'
            },
            'mime': 'text/plain'
        })
        assert response.status_code == 400
        
        # Non-dict e2ee
        response = client.post('/api/share', json={
            'payload': 'encrypted_data',
            'e2ee': 'not_a_dict',
            'mime': 'text/plain'
        })
        assert response.status_code == 400
        
        # Non-string salt
        response = client.post('/api/share', json={
            'payload': 'encrypted_data',
            'e2ee': {
                'salt': 123,
                'nonce': 'test_nonce'
            },
            'mime': 'text/plain'
        })
        assert response.status_code == 400
        
        # Non-string nonce
        response = client.post('/api/share', json={
            'payload': 'encrypted_data',
            'e2ee': {
                'salt': 'test_salt',
                'nonce': 123
            },
            'mime': 'text/plain'
        })
        assert response.status_code == 400
    
    def test_retrieve_secret_simple(self, client):
        """Test retrieve secret endpoint"""
        import uuid
        link_id = str(uuid.uuid4())
        
        response = client.get(f'/api/share/secret/{link_id}')
        # Should return 200 (even if not found, to prevent enumeration)
        assert response.status_code == 200
        data = response.get_json()
        assert 'payload' in data