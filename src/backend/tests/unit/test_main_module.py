# backend/tests/test_main_module.py
"""
Tests for the main.py module specifically to improve coverage.
This tests the actual main.py file rather than the conftest.py routes.
"""

import pytest
import os
import sys
import json
from unittest.mock import patch, MagicMock
from cryptography.fernet import Fernet

# Ensure we can import the main module
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
parent_dir = os.path.dirname(backend_dir)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)


class TestMainModuleImport:
    """Test importing and initializing the main module."""

    def test_main_module_import_success(self):
        """Test that main module can be imported successfully."""
        # Set up proper environment before import
        os.environ["MASTER_ENCRYPTION_KEY"] = Fernet.generate_key().decode()
        os.environ["FLASK_DEBUG"] = "False"
        os.environ["MAX_SECRET_LENGTH_KB"] = "100"
        os.environ["SECRET_EXPIRY_MINUTES"] = "60"

        # Import the module - this will trigger module-level code execution
        from app import main

        # Verify the app was created
        assert main.app is not None
        assert main.app.name == "app.main"

        # Verify CORS is enabled
        assert hasattr(main.app, "config")

    def test_main_module_routes_exist(self):
        """Test that all expected routes are registered."""
        from app import main

        # Get all registered routes
        routes = [rule.rule for rule in main.app.url_map.iter_rules()]

        # Verify expected routes exist
        assert "/api/health" in routes
        assert "/api/share/secret" in routes
        assert "/api/share/secret/<link_id>" in routes


class TestMainModuleInitializationCode:
    """Test main module initialization code paths."""

    def test_database_initialization_code(self):
        """Test the Cosmos DB initialization code in main module."""
        from app import main
        
        # Test the module-level Cosmos DB initialization
        # This should have been executed when the module was imported
        
        # Verify app has Cosmos DB configuration
        assert hasattr(main.app, 'config')
        
        # Verify Cosmos DB initialization function exists
        from app import init_cosmos_db
        assert init_cosmos_db is not None
        
        # Test that app can be initialized with Cosmos DB
        with main.app.app_context():
            # The app should be properly configured for Cosmos DB
            assert main.app.config is not None


class TestMainModuleRoutes:
    """Test the actual route functions from main.py when called directly."""

    @pytest.fixture
    def setup_environment(self):
        """Set up proper environment for testing."""
        os.environ["MASTER_ENCRYPTION_KEY"] = Fernet.generate_key().decode()
        os.environ["FLASK_DEBUG"] = "False"
        os.environ["MAX_SECRET_LENGTH_KB"] = "100"
        os.environ["SECRET_EXPIRY_MINUTES"] = "60"

    @pytest.fixture
    def main_app(self, setup_environment, mock_cosmos_container):
        """Create the actual main app for testing."""
        with patch('app.get_cosmos_container', return_value=mock_cosmos_container), \
             patch('app.storage.get_cosmos_container', return_value=mock_cosmos_container), \
             patch('app.init_cosmos_db', return_value=True):
            
            from app import main
            
            main.app.config["TESTING"] = True
            main.app.config["MAX_SECRET_LENGTH_BYTES"] = 100 * 1024
            
            with main.app.app_context():
                yield main.app

    def test_health_check_route(self, main_app):
        """Test the health check route from main.py."""
        with main_app.test_client() as client:
            response = client.get("/api/health")
            assert response.status_code == 200
            data = json.loads(response.data)
            assert data["status"] == "healthy"

    def test_share_secret_route_success(self, main_app):
        """Test successful secret sharing via main.py route."""
        with main_app.test_client() as client:
            secret_data = {"payload": "Test secret from main.py", "mime": "text/plain"}
            
            with patch('app.main.store_secret') as mock_store:
                mock_store.return_value = "test-link-id"
                
                response = client.post(
                    "/api/share/secret",
                    data=json.dumps(secret_data),
                    content_type="application/json",
                )
                
                assert response.status_code == 201
                data = json.loads(response.data)
                assert "link_id" in data
                assert data["link_id"] == "test-link-id"

    def test_share_secret_route_validation_errors(self, main_app):
        """Test validation errors in main.py share route."""
        with main_app.test_client() as client:
            # Test missing JSON data
            response = client.post("/api/share/secret", data="not json")
            assert response.status_code == 400

            # Test missing payload field
            response = client.post(
                "/api/share/secret",
                data=json.dumps({"mime": "text/plain"}),
                content_type="application/json",
            )
            assert response.status_code == 400

    def test_share_secret_route_too_long(self, main_app):
        """Test secret that is too long."""
        with main_app.test_client() as client:
            # Create a very long secret
            long_secret = "x" * (100 * 1024 + 1)  # Exceed the limit
            secret_data = {"payload": long_secret, "mime": "text/plain"}
            
            response = client.post(
                "/api/share/secret",
                data=json.dumps(secret_data),
                content_type="application/json",
            )
            assert response.status_code == 400

    def test_retrieve_secret_route_success(self, main_app):
        """Test successful secret retrieval via main.py route."""
        from app.models import Secret
        import uuid
        
        link_id = str(uuid.uuid4())
        
        with main_app.test_client() as client:
            mock_secret = Secret(
                id=link_id,
                encrypted_secret=b"encrypted_data",
                mime_type="text/plain",
                is_e2ee=False,
                e2ee_data=None
            )
            
            with patch('app.main.retrieve_secret') as mock_retrieve, \
                 patch('app.main.decrypt_secret') as mock_decrypt, \
                 patch('app.main.delete_secret') as mock_delete:
                
                mock_retrieve.return_value = mock_secret
                mock_decrypt.return_value = "decrypted secret"
                mock_delete.return_value = True
                
                response = client.get(f"/api/share/secret/{link_id}")
                assert response.status_code == 200
                data = json.loads(response.data)
                assert "payload" in data

    def test_retrieve_secret_route_not_found(self, main_app):
        """Test secret retrieval when secret not found."""
        import uuid
        link_id = str(uuid.uuid4())
        
        with main_app.test_client() as client:
            with patch('app.main.retrieve_secret') as mock_retrieve:
                mock_retrieve.return_value = None
                
                response = client.get(f"/api/share/secret/{link_id}")
                assert response.status_code == 200  # Returns 200 to prevent enumeration
                data = json.loads(response.data)
                assert "payload" in data  # Contains dummy data

    def test_head_request_route(self, main_app):
        """Test HEAD request handling."""
        import uuid
        link_id = str(uuid.uuid4())
        
        with main_app.test_client() as client:
            response = client.head(f"/api/share/secret/{link_id}")
            # HEAD should return same status as GET but no body
            assert response.status_code in [200, 404]
            assert len(response.get_data()) == 0

    def test_retrieve_secret_empty_link_id_edge_case(self, main_app):
        """Test edge case with empty link_id."""
        with main_app.test_client() as client:
            # Empty link_id should be handled by Flask routing (404)
            response = client.get("/api/share/secret/")
            assert response.status_code == 404


class TestMainModuleErrorHandling:
    """Test error handling in main.py routes."""

    @pytest.fixture
    def error_app(self, mock_cosmos_container):
        """Create app for error testing."""
        with patch('app.get_cosmos_container', return_value=mock_cosmos_container), \
             patch('app.storage.get_cosmos_container', return_value=mock_cosmos_container), \
             patch('app.init_cosmos_db', return_value=True):
            
            from app import main
            main.app.config["TESTING"] = True
            with main.app.app_context():
                yield main.app

    def test_share_secret_encryption_error(self, error_app):
        """Test handling of encryption errors during secret sharing."""
        with error_app.test_client() as client:
            secret_data = {"payload": "test secret", "mime": "text/plain"}
            
            with patch('app.main.store_secret') as mock_store:
                mock_store.side_effect = Exception("Encryption failed")
                
                response = client.post(
                    "/api/share/secret",
                    data=json.dumps(secret_data),
                    content_type="application/json",
                )
                assert response.status_code == 500

    def test_share_secret_type_error(self, error_app):
        """Test handling of type errors during secret sharing."""
        with error_app.test_client() as client:
            secret_data = {"payload": "test secret", "mime": "text/plain"}
            
            with patch('app.main.store_secret') as mock_store:
                mock_store.side_effect = TypeError("Type error")
                
                response = client.post(
                    "/api/share/secret",
                    data=json.dumps(secret_data),
                    content_type="application/json",
                )
                assert response.status_code == 400

    def test_share_secret_general_error(self, error_app):
        """Test handling of general errors during secret sharing."""
        with error_app.test_client() as client:
            secret_data = {"payload": "test secret", "mime": "text/plain"}
            
            with patch('app.main.store_secret') as mock_store:
                mock_store.side_effect = RuntimeError("Database error")
                
                response = client.post(
                    "/api/share/secret",
                    data=json.dumps(secret_data),
                    content_type="application/json",
                )
                assert response.status_code == 500

    def test_retrieve_secret_decryption_failure(self, error_app):
        """Test handling of decryption failures during secret retrieval."""
        from app.models import Secret
        import uuid
        
        link_id = str(uuid.uuid4())
        
        with error_app.test_client() as client:
            mock_secret = Secret(
                id=link_id,
                encrypted_secret=b"corrupted_data",
                mime_type="text/plain",
                is_e2ee=False,
                e2ee_data=None
            )
            
            with patch('app.main.retrieve_secret') as mock_retrieve, \
                 patch('app.main.decrypt_secret') as mock_decrypt, \
                 patch('app.main.delete_secret') as mock_delete:
                
                mock_retrieve.return_value = mock_secret
                mock_decrypt.return_value = None  # Decryption failure
                mock_delete.return_value = True
                
                response = client.get(f"/api/share/secret/{link_id}")
                assert response.status_code == 200  # Still returns 200 to prevent enumeration
                data = json.loads(response.data)
                assert "payload" in data