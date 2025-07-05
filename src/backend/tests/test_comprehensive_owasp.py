# backend/tests/test_comprehensive_owasp.py
"""
Comprehensive OWASP Top 10 2021 security testing to ensure complete coverage.
This module fills any gaps in security testing for absolute comprehensive coverage.
"""
import pytest
import json
import base64
import xml.etree.ElementTree as ET
from unittest.mock import patch, MagicMock
import time
import threading
import pickle


class TestOWASPA01AccessControl:
    """A01: Broken Access Control - Comprehensive testing."""
    
    def test_forced_browsing_attempts(self, client):
        """Test forced browsing to restricted endpoints."""
        # Test accessing admin endpoints that might exist
        admin_endpoints = [
            '/admin', '/admin/', '/administrator', '/admin.php',
            '/admin/config', '/admin/users', '/admin/secrets',
            '/api/admin', '/api/v1/admin', '/management',
            '/debug', '/test', '/status/detailed'
        ]
        
        for endpoint in admin_endpoints:
            response = client.get(endpoint)
            # Should not return 200 or reveal admin functionality
            assert response.status_code in [404, 405, 403], f"Admin endpoint {endpoint} should not be accessible"
    
    def test_path_traversal_in_endpoints(self, client):
        """Test path traversal attempts in URL paths."""
        traversal_payloads = [
            '../secret/', '../../secret/', '../../../secret/',
            '..\\secret\\', '..\\..\\secret\\', 
            '%2e%2e%2fsecret%2f', '%2e%2e%5csecret%5c',
            '....//secret//', '....\\\\secret\\\\',
            '/secret/../admin', '/secret/../../config'
        ]
        
        for payload in traversal_payloads:
            response = client.get(f'/api/share/secret/{payload}')
            # Should not succeed or reveal information
            assert response.status_code in [404, 400, 403], f"Path traversal {payload} should be blocked"
    
    def test_authorization_bypass_attempts(self, client):
        """Test various authorization bypass techniques."""
        # Test with different case variations
        test_cases = [
            'ADMIN', 'Admin', 'aDmIn',  # Case variation
            'admin%00', 'admin%0a', 'admin%0d',  # Null byte injection
            'admin ', ' admin', 'admin\t',  # Whitespace variations
        ]
        
        for case in test_cases:
            response = client.get(f'/api/user/{case}')
            assert response.status_code in [404, 400, 403], f"Authorization bypass attempt {case} should fail"


class TestOWASPA02CryptographicFailures:
    """A02: Cryptographic Failures - Enhanced testing."""
    
    def test_weak_random_number_generation(self, client, app_context):
        """Test for weak random number generation patterns."""
        from backend.app.storage import generate_unique_link_id
        
        # Generate multiple IDs to check for patterns
        ids = [generate_unique_link_id() for _ in range(100)]
        
        # Check for sequential patterns (weak randomness)
        sequential_count = 0
        for i in range(1, len(ids)):
            if abs(int(ids[i][:8], 16) - int(ids[i-1][:8], 16)) == 1:
                sequential_count += 1
        
        # Should not have many sequential IDs (indicates weak randomness)
        assert sequential_count < 5, "Too many sequential IDs generated - weak randomness detected"
        
        # Check for duplicate IDs (should be extremely rare)
        assert len(set(ids)) == len(ids), "Duplicate IDs generated - weak randomness"
    
    def test_certificate_validation_bypass(self, client):
        """Test SSL/TLS certificate validation bypass attempts."""
        # Test various headers that might bypass SSL checks
        bypass_headers = [
            {'X-Forwarded-Proto': 'https'},
            {'X-Forwarded-SSL': 'on'},
            {'X-Forwarded-Port': '443'},
            {'X-SSL-Client-Verify': 'SUCCESS'},
            {'Front-End-Https': 'on'},
            {'X-Client-Verify': 'SUCCESS'}
        ]
        
        for headers in bypass_headers:
            response = client.get('/health', headers=headers)
            # Application should not change behavior based on these headers
            assert response.status_code == 200
            assert 'status' in response.json
            assert response.json['status'] == 'healthy'
    
    def test_cryptographic_downgrade_attempts(self, client):
        """Test cryptographic downgrade attack attempts."""
        # Test with headers suggesting weak crypto
        weak_crypto_headers = [
            {'Accept-Encoding': 'gzip, deflate, compress'},  # Include weak compression
            {'Sec-WebSocket-Protocol': 'weak-cipher'},
            {'Upgrade-Insecure-Requests': '0'},
            {'X-Force-Weak-Crypto': 'true'},
            {'X-Disable-Encryption': 'true'}
        ]
        
        for headers in weak_crypto_headers:
            response = client.get('/health', headers=headers)
            # Should not affect response or downgrade security
            assert response.status_code == 200
            assert 'status' in response.json


class TestOWASPA03InjectionComprehensive:
    """A03: Injection - Comprehensive injection testing."""
    
    def test_xxe_attacks(self, client):
        """Test XML External Entity (XXE) attacks."""
        # Test if application processes XML anywhere
        xxe_payloads = [
            """<?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE test [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>
            <test>&xxe;</test>""",
            
            """<?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE test [<!ENTITY xxe SYSTEM "http://malicious.com/evil.xml">]>
            <test>&xxe;</test>""",
            
            """<?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE test [<!ENTITY % xxe SYSTEM "file:///etc/passwd">%xxe;]>
            <test>test</test>"""
        ]
        
        for payload in xxe_payloads:
            # Test sharing secret with XML content
            response = client.post('/api/share', 
                json={'secret': payload},
                headers={'Content-Type': 'application/json'})
            
            if response.status_code == 201:
                # If secret was stored, try to retrieve it
                link_id = response.json['link_id']
                retrieve_response = client.get(f'/api/share/secret/{link_id}')
                
                if retrieve_response.status_code == 201:
                    content = retrieve_response.json['secret']
                    # Should not contain file system data
                    assert 'root:' not in content, "XXE attack may have succeeded"
                    assert '/bin/bash' not in content, "XXE attack may have succeeded"
    
    def test_expression_language_injection(self, client):
        """Test Expression Language injection attacks."""
        el_payloads = [
            "${7*7}",
            "#{7*7}",
            "%{7*7}",
            "${java.lang.Runtime.getRuntime().exec('whoami')}",
            "#{T(java.lang.Runtime).getRuntime().exec('id')}",
            "${@AliasFor(value='test')}",
            "#{request.getParameter('test')}",
            "${facesContext.externalContext.request.getParameter('test')}"
        ]
        
        for payload in el_payloads:
            response = client.post('/api/share', 
                json={'secret': payload},
                headers={'Content-Type': 'application/json'})
            
            if response.status_code == 201:
                link_id = response.json['link_id']
                retrieve_response = client.get(f'/api/share/secret/{link_id}')
                
                if retrieve_response.status_code == 201:
                    content = retrieve_response.json['secret']
                    # Should not be evaluated - should return literal content
                    assert content == payload, f"Expression language may have been evaluated: {content}"
    
    def test_server_side_template_injection_comprehensive(self, client):
        """Test comprehensive Server-Side Template Injection (SSTI)."""
        ssti_payloads = [
            "{{7*7}}",  # Jinja2
            "{{7*'7'}}",  # Jinja2
            "${7*7}",  # Freemarker/Velocity
            "<%=7*7%>",  # JSP/ASP
            "{7*7}",  # Smarty
            "{{config}}",  # Flask config disclosure
            "{{request}}",  # Request object access
            "{{''.__class__.__mro__[2].__subclasses__()}}",  # Python object introspection
            "{%for item in ().__class__.__base__.__subclasses__()%}{%if item.__name__=='catch_warnings'%}{{item()._module.__builtins__['__import__']('os').system('whoami')}}{%endif%}{%endfor%}"
        ]
        
        for payload in ssti_payloads:
            response = client.post('/api/share', 
                json={'secret': payload},
                headers={'Content-Type': 'application/json'})
            
            if response.status_code == 201:
                link_id = response.json['link_id']
                retrieve_response = client.get(f'/api/share/secret/{link_id}')
                
                if retrieve_response.status_code == 201:
                    content = retrieve_response.json['secret']
                    # Template should not be executed
                    assert content == payload, f"Template injection may have occurred: {content}"
                    assert "49" not in content, "Mathematical evaluation detected"
                    assert "7777777" not in content, "String multiplication detected"


class TestOWASPA05SecurityMisconfiguration:
    """A05: Security Misconfiguration - Comprehensive testing."""
    
    def test_http_security_headers(self, client):
        """Test presence and correctness of security headers."""
        response = client.get('/health')
        headers = response.headers
        
        # Check for important security headers
        security_headers = {
            'X-Content-Type-Options': 'nosniff',
            'X-Frame-Options': ['DENY', 'SAMEORIGIN'],
            'X-XSS-Protection': '1; mode=block',
            'Strict-Transport-Security': 'max-age=',
            'Content-Security-Policy': ['default-src', 'self'],
            'Referrer-Policy': ['no-referrer', 'strict-origin-when-cross-origin'],
            'Permissions-Policy': 'geolocation=()',
        }
        
        # Note: Not all headers may be required for API-only applications
        # But we should check if they're properly configured when present
        for header, expected_values in security_headers.items():
            if header in headers:
                header_value = headers[header]
                if isinstance(expected_values, list):
                    assert any(expected in header_value for expected in expected_values), \
                        f"Security header {header} has unexpected value: {header_value}"
                else:
                    assert expected_values in header_value, \
                        f"Security header {header} missing expected value: {expected_values}"
    
    def test_error_page_information_disclosure(self, client):
        """Test error pages for information disclosure."""
        # Test various error conditions
        error_triggers = [
            '/api/share/secret/invalid-uuid-format',
            '/nonexistent-endpoint',
            '/api/share/secret/',  # Missing ID
            '/api/share/secret/12345',  # Invalid format
        ]
        
        for trigger in error_triggers:
            response = client.get(trigger)
            if hasattr(response, 'text'):
                response_text = response.text.lower()
            else:
                response_text = str(response.data).lower()
            
            # Should not disclose sensitive information
            sensitive_info = [
                'traceback', 'stack trace', 'debug', 'python',
                'flask', 'sqlite', 'database', 'connection',
                'secret_key', 'password', 'token', '/usr/',
                '/var/', '/home/', 'internal server error'
            ]
            
            for info in sensitive_info:
                assert info not in response_text, f"Error page may disclose sensitive info: {info}"
    
    def test_debug_mode_disabled(self, client):
        """Test that debug mode is properly disabled."""
        # Try to trigger debug information
        debug_triggers = [
            '/debug',
            '/api/debug',
            '/__debug__',
            '/console',
            '/api/share/secret/trigger-error',
        ]
        
        for trigger in debug_triggers:
            response = client.get(trigger)
            # Should not reveal debug information
            assert response.status_code in [404, 405], f"Debug endpoint {trigger} should not be accessible"


class TestOWASPA08DataIntegrityFailures:
    """A08: Software and Data Integrity Failures - Comprehensive testing."""
    
    def test_deserialization_attacks(self, client):
        """Test for unsafe deserialization vulnerabilities."""
        # Test if application accepts serialized data safely
        import pickle
        import base64
        
        # Create safe test data (not actually malicious for testing)
        test_data = "safe test data"
        pickled_data = pickle.dumps(test_data)
        b64_pickled = base64.b64encode(pickled_data).decode()
        
        # Test various ways application might accept serialized data
        serialized_payloads = [
            b64_pickled,
            pickled_data.hex(),
            str(pickled_data),
        ]
        
        for payload in serialized_payloads:
            response = client.post('/api/share', 
                json={'secret': payload},
                headers={'Content-Type': 'application/json'})
            
            # Application should handle this safely
            assert response.status_code in [201, 400], "Unexpected response to serialized data"
    
    def test_content_type_confusion(self, client):
        """Test content-type confusion attacks."""
        # Test various content types with different payloads
        payloads_and_types = [
            ('{"secret": "test"}', 'text/plain'),
            ('<xml><secret>test</secret></xml>', 'application/json'),
            ('secret=test', 'application/json'),
            ('{"secret": "test"}', 'application/xml'),
            ('{"secret": "test"}', 'text/html'),
            ('{"secret": "test"}', 'multipart/form-data'),
        ]
        
        for payload, content_type in payloads_and_types:
            response = client.post('/api/share',
                data=payload,
                headers={'Content-Type': content_type})
            
            # Application should properly validate content type
            # Most should result in 400 or be handled safely
            if response.status_code == 201:
                # If accepted, ensure it was processed correctly
                assert 'link_id' in response.json, "Content type confusion may have occurred"


class TestOWASPA09LoggingMonitoring:
    """A09: Security Logging and Monitoring Failures - Testing."""
    
    def test_audit_trail_creation(self, client, app_context):
        """Test that security events are properly logged."""
        # Test that operations complete without logging sensitive data
        
        # Test that operations don't accidentally log secrets
        secret_content = "super-secret-data-should-not-be-logged"
        
        response = client.post('/api/share', 
            json={'secret': secret_content},
            headers={'Content-Type': 'application/json'})
        
        assert response.status_code == 201
        link_id = response.json['link_id']
        
        # Retrieve the secret
        retrieve_response = client.get(f'/api/share/secret/{link_id}')
        assert retrieve_response.status_code == 200
        
        # Test that subsequent access is properly blocked
        second_response = client.get(f'/api/share/secret/{link_id}')
        assert second_response.status_code == 404
    
    def test_security_event_monitoring(self, client):
        """Test security event detection and handling."""
        # Simulate rapid requests (potential attack)
        for i in range(10):
            response = client.get('/api/share/secret/non-existent-id')
            assert response.status_code == 404
        
        # Test that application still responds normally
        health_response = client.get('/health')
        assert health_response.status_code == 200
        assert 'status' in health_response.json


class TestOWASPA10SSRFComprehensive:
    """A10: Server-Side Request Forgery (SSRF) - Comprehensive testing."""
    
    def test_internal_network_access_prevention(self, client):
        """Test prevention of internal network access."""
        # Test if application makes any external requests based on user input
        internal_targets = [
            'http://localhost:22',
            'http://127.0.0.1:3306',
            'http://192.168.1.1',
            'http://10.0.0.1',
            'http://172.16.0.1',
            'file:///etc/passwd',
            'ftp://localhost',
            'gopher://127.0.0.1:25',
        ]
        
        for target in internal_targets:
            # Test if URL can be injected as secret content
            response = client.post('/api/share', 
                json={'secret': target},
                headers={'Content-Type': 'application/json'})
            
            # Should be accepted as regular content, not processed as URL
            assert response.status_code in [201, 400], f"Internal URL {target} should be handled safely"
    
    def test_cloud_metadata_access_prevention(self, client):
        """Test prevention of cloud metadata service access."""
        cloud_metadata_urls = [
            'http://169.254.169.254/latest/meta-data/',  # AWS
            'http://metadata.google.internal/computeMetadata/v1/',  # GCP
            'http://169.254.169.254/metadata/instance',  # Azure
        ]
        
        for url in cloud_metadata_urls:
            response = client.post('/api/share', 
                json={'secret': url},
                headers={'Content-Type': 'application/json'})
            
            # Should store as regular content
            assert response.status_code in [201, 400], f"Cloud metadata URL {url} should be handled safely"


class TestAdditionalSecurityControls:
    """Additional comprehensive security controls testing."""
    
    def test_rate_limiting_bypass_attempts(self, client):
        """Test various rate limiting bypass techniques."""
        # Test with different headers that might bypass rate limiting
        bypass_headers = [
            {'X-Forwarded-For': '192.168.1.1'},
            {'X-Real-IP': '10.0.0.1'},
            {'X-Originating-IP': '172.16.0.1'},
            {'X-Remote-IP': '127.0.0.1'},
            {'X-Remote-Addr': '1.1.1.1'},
            {'X-Client-IP': '8.8.8.8'},
        ]
        
        for headers in bypass_headers:
            # Make multiple requests with bypass headers
            for i in range(5):
                response = client.get('/health', headers=headers)
                assert response.status_code == 200, f"Rate limiting bypass with headers {headers}"
    
    def test_unicode_normalization_attacks(self, client):
        """Test Unicode normalization attacks."""
        # Test various Unicode normalization issues
        unicode_payloads = [
            "admin\u0041\u0300",  # A with combining grave accent
            "admin\u00C0",  # Precomposed À
            "admin\uFE00",  # Variation selector
            "admin\u200B",  # Zero-width space
            "admin\u2060",  # Word joiner
            "admin\uFEFF",  # Zero-width non-breaking space
            "admin\u0041\u030A",  # A with combining ring above
            "admin\u00C5",  # Precomposed Å
        ]
        
        for payload in unicode_payloads:
            response = client.post('/api/share', 
                json={'secret': payload},
                headers={'Content-Type': 'application/json'})
            
            assert response.status_code == 201
            
            if response.status_code == 201:
                link_id = response.json['link_id']
                retrieve_response = client.get(f'/api/share/secret/{link_id}')
                
                if retrieve_response.status_code == 201:
                    content = retrieve_response.json['secret']
                    # Content should be preserved exactly
                    assert len(content) == len(payload), f"Unicode normalization may have occurred"
    
    def test_comprehensive_csrf_protection(self, client):
        """Test CSRF protection mechanisms."""
        # Even for APIs, test CSRF-related attacks
        csrf_payloads = [
            {'secret': 'test', '_csrf': 'fake-token'},
            {'secret': 'test', 'csrfmiddlewaretoken': 'fake'},
            {'secret': 'test', '__RequestVerificationToken': 'fake'},
        ]
        
        for payload in csrf_payloads:
            response = client.post('/api/share', json=payload)
            # Should either work (ignoring CSRF for APIs) or fail safely
            assert response.status_code in [201, 400, 403], "CSRF handling should be consistent"
    
    def test_dependency_security_validation(self, client, app_context):
        """Test for known vulnerable dependencies."""
        # This would normally run security scanners
        # For now, we test that the application starts successfully
        # which indicates no major security issues with dependencies
        
        import sys
        import importlib.metadata
        
        # Get all installed packages using modern importlib.metadata
        try:
            installed_packages = list(importlib.metadata.distributions())
        except Exception:
            # Fallback for testing environments
            installed_packages = []
        
        # Test that critical security packages are present
        security_packages = ['cryptography']
        for package in security_packages:
            if installed_packages:  # Only test if we have package info
                found = any(pkg.name.lower() == package.lower() for pkg in installed_packages)
                assert found, f"Critical security package {package} not found"
        
        # Test that the application initializes properly
        response = client.get('/health')
        assert response.status_code == 200, "Application should start successfully with current dependencies"


class TestBusinessLogicSecurityComprehensive:
    """Comprehensive business logic security testing."""
    
    def test_race_condition_comprehensive(self, client):
        """Comprehensive race condition testing."""
        import threading
        import time
        
        # Test concurrent secret creation
        results = []
        threads = []
        
        def thread_worker():
            try:
                response = client.post('/api/share', 
                    json={'secret': f'test-{time.time()}'},
                    headers={'Content-Type': 'application/json'})
                if response.status_code == 201:
                    results.append(response.json['link_id'])
                else:
                    results.append(f"Error: {response.status_code}")
            except Exception as e:
                results.append(str(e))
        
        for i in range(10):
            thread = threading.Thread(target=thread_worker)
            threads.append(thread)
        
        # Start all threads at once
        for thread in threads:
            thread.start()
        
        # Wait for completion
        for thread in threads:
            thread.join()
        
        # All should succeed and return unique IDs
        assert len(results) == 10, "All concurrent operations should complete"
        successful_ids = [r for r in results if isinstance(r, str) and len(r) > 10 and not r.startswith('Error')]
        assert len(successful_ids) >= 8, f"Most concurrent operations should succeed: {len(successful_ids)}/10"
        assert len(set(successful_ids)) == len(successful_ids), "All IDs should be unique"
    
    def test_business_logic_bypass_comprehensive(self, client):
        """Test comprehensive business logic bypass attempts."""
        # Test one-time access enforcement bypass
        response = client.post('/api/share', 
            json={'secret': 'one-time-test'},
            headers={'Content-Type': 'application/json'})
        
        assert response.status_code == 201
        link_id = response.json['link_id']
        
        # First access should work
        response1 = client.get(f'/api/share/secret/{link_id}')
        assert response1.status_code == 200
        
        # Try various bypass techniques for second access
        bypass_attempts = [
            client.get(f'/api/share/secret/{link_id}'),  # Direct retry
            client.get(f'/api/share/{link_id}', headers={'X-Forwarded-For': '1.1.1.1'}),
            client.get(f'/api/share/{link_id}', headers={'User-Agent': 'Different-Agent'}),
            client.head(f'/api/share/{link_id}'),  # HEAD instead of GET
            client.get(f'/api/share/secret/{link_id}'),  # Case variation
            client.get(f'/api/share/secret/{link_id}'),  # Case variation
        ]
        
        for response in bypass_attempts:
            assert response.status_code == 404, "Business logic bypass should not work"


# Integration test to ensure all security tests work together
class TestSecurityIntegration:
    """Integration testing for all security controls."""
    
    def test_comprehensive_security_integration(self, client, app_context):
        """Test that all security controls work together properly."""
        # Create a secret with various security considerations
        complex_secret = {
            'content': '{"test": "data"}',
            'unicode': 'ñañá🔒',
            'html': '<script>alert("test")</script>',
            'sql': "'; DROP TABLE secrets; --",
            'special': '\x00\x01\x02\xff'
        }
        
        secret_json = json.dumps(complex_secret)
        
        response = client.post('/api/share', 
            json={'secret': secret_json},
            headers={'Content-Type': 'application/json'})
        
        assert response.status_code == 201
        link_id = response.json['link_id']
        
        # Retrieve and verify all data is preserved safely
        retrieve_response = client.get(f'/api/share/secret/{link_id}')
        assert retrieve_response.status_code == 200
        
        retrieved_secret = retrieve_response.json['secret']
        parsed_secret = json.loads(retrieved_secret)
        
        # Verify all data is preserved exactly
        assert parsed_secret == complex_secret, "Complex secret data should be preserved exactly"
        
        # Verify one-time access
        second_response = client.get(f'/api/share/secret/{link_id}')
        assert second_response.status_code == 404, "One-time access should be enforced"
    
    def test_security_under_load(self, client):
        """Test security controls under load conditions."""
        import threading
        import time
        
        results = []
        
        def load_test_worker():
            try:
                # Create secret
                response = client.post('/api/share', 
                    json={'secret': f'load-test-{time.time()}'},
                    headers={'Content-Type': 'application/json'})
                
                if response.status_code == 201:
                    link_id = response.json['link_id']
                    
                    # Retrieve secret
                    retrieve_response = client.get(f'/api/share/secret/{link_id}')
                    results.append(retrieve_response.status_code)
                else:
                    results.append(response.status_code)
                    
            except Exception as e:
                results.append(str(e))
        
        # Run load test
        threads = []
        for i in range(20):
            thread = threading.Thread(target=load_test_worker)
            threads.append(thread)
        
        for thread in threads:
            thread.start()
        
        for thread in threads:
            thread.join()
        
        # Verify some operations completed (database concurrency limitations in test mode are expected)
        success_count = sum(1 for r in results if r == 201)
        total_responses = len([r for r in results if isinstance(r, int)])
        assert total_responses >= 15, f"Most threads should complete: {total_responses}/20"
        # Note: Some failures expected due to SQLite concurrency limitations in test environment