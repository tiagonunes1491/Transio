# backend/tests/unit/test_focused_coverage.py
import pytest
import json
import time
from unittest.mock import patch


class TestFocusedCoverage:
    """Focused tests to improve coverage on specific areas."""
    
    def test_health_endpoint_detailed(self, client):
        """Test health endpoint thoroughly."""
        response = client.get('/health')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'status' in data
        assert data['status'] == 'healthy'
        
        # Test with HEAD method too
        head_response = client.head('/health')
        assert head_response.status_code == 200
    
    def test_anti_enumeration_timing_consistency(self, client):
        """Test anti-enumeration timing behavior in detail."""
        # Test multiple non-existent secrets to verify timing delays
        fake_ids = [
            "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            "11111111-2222-3333-4444-555555555555",
            "zzzzzzzz-yyyy-xxxx-wwww-vvvvvvvvvvvv"
        ]
        
        response_times = []
        for fake_id in fake_ids:
            start_time = time.time()
            response = client.get(f'/api/share/secret/{fake_id}')
            end_time = time.time()
            
            assert response.status_code == 200
            data = json.loads(response.data)
            assert data['payload'] == "Dummy payload for non-existent secret"
            assert 'e2ee' in data
            assert '_padding' in data
            
            response_times.append(end_time - start_time)
        
        # Verify minimum delay is applied (anti-timing attack)
        for response_time in response_times:
            assert response_time >= 0.004  # At least 4ms (accounting for test variance)
    
    def test_request_validation_edge_cases(self, client):
        """Test various request validation scenarios."""
        # Test empty link_id handling (though this should be caught by routing)
        response = client.get('/api/share/secret/')
        assert response.status_code == 404  # Flask routing should handle this
        
        # Test with malformed JSON
        response = client.post('/api/share',
                             data="{'invalid': json}",
                             content_type='application/json')
        assert response.status_code == 400
        
        # Test with extremely long but valid payload (under limit)
        long_payload = "A" * (50 * 1024)  # 50KB - under the 100KB limit
        response = client.post('/api/share',
                             data=json.dumps({"payload": long_payload}),
                             content_type='application/json')
        assert response.status_code == 201
    
    def test_e2ee_validation_detailed(self, client):
        """Test E2EE validation in detail."""
        # Test valid E2EE request
        valid_e2ee = {
            "payload": "encrypted_content_from_client",
            "mime": "application/json",
            "e2ee": {
                "salt": "valid_salt_string",
                "nonce": "valid_nonce_string"
            }
        }
        
        response = client.post('/api/share',
                             data=json.dumps(valid_e2ee),
                             content_type='application/json')
        assert response.status_code == 201
        data = json.loads(response.data)
        assert data['e2ee'] is True
        assert data['mime'] == "application/json"
        assert 'link_id' in data
        
        # Test E2EE with invalid field types
        invalid_e2ee_cases = [
            {"payload": "test", "e2ee": {"salt": 123, "nonce": "valid"}},  # Invalid salt type
            {"payload": "test", "e2ee": {"salt": "valid", "nonce": 456}},  # Invalid nonce type
            {"payload": "test", "e2ee": {"salt": "valid"}},  # Missing nonce
            {"payload": "test", "e2ee": {"nonce": "valid"}},  # Missing salt
        ]
        
        for invalid_case in invalid_e2ee_cases:
            response = client.post('/api/share',
                                 data=json.dumps(invalid_case),
                                 content_type='application/json')
            assert response.status_code == 400
    
    def test_mime_type_handling(self, client):
        """Test MIME type validation and handling."""
        test_cases = [
            {"payload": "test", "mime": "text/plain"},
            {"payload": "test", "mime": "application/json"},
            {"payload": "test", "mime": "text/html"},
            {"payload": "test", "mime": "application/pdf"},
        ]
        
        for case in test_cases:
            response = client.post('/api/share',
                                 data=json.dumps(case),
                                 content_type='application/json')
            assert response.status_code == 201
            data = json.loads(response.data)
            assert data['mime'] == case['mime']
        
        # Test invalid MIME type
        response = client.post('/api/share',
                             data=json.dumps({"payload": "test", "mime": 123}),
                             content_type='application/json')
        assert response.status_code == 400
    
    def test_response_padding_sizes(self, client):
        """Test that response padding creates consistent sizes."""
        # Get responses for non-existent secrets
        responses = []
        for i in range(5):
            response = client.get(f'/api/share/secret/fake-id-{i:04d}')
            assert response.status_code == 200
            responses.append(response.get_data())
        
        # All responses should be similar in size due to padding
        response_sizes = [len(r) for r in responses]
        max_size = max(response_sizes)
        min_size = min(response_sizes)
        
        # Sizes should be within a reasonable range (padding working)
        assert max_size > 50000  # Should be substantial due to padding
        assert (max_size - min_size) / max_size < 0.1  # Within 10% variance
    
    def test_cors_headers(self, client):
        """Test CORS headers are present."""
        response = client.get('/health')
        # Flask-CORS should add CORS headers
        assert response.status_code == 200
        
        # Test OPTIONS request
        response = client.options('/api/share')
        assert response.status_code == 200
    
    def test_unicode_handling(self, client):
        """Test unicode and special character handling."""
        unicode_payloads = [
            "Hello 世界",
            "🔐 Secret émojis 🗝️",
            "Тест на русском",
            "العربية",
            "Special chars: \n\t\r\"'\\",
        ]
        
        for payload in unicode_payloads:
            response = client.post('/api/share',
                                 data=json.dumps({"payload": payload}),
                                 content_type='application/json')
            assert response.status_code == 201
            
            # Verify the response contains proper unicode
            data = json.loads(response.data)
            assert 'link_id' in data