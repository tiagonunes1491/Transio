# backend/tests/test_models.py
import pytest
import uuid
from datetime import datetime, timezone, timedelta

from app.models import Secret


class TestSecretModel:
    """Test cases for the Secret model."""
    
    def test_secret_creation(self):
        """Test creating a Secret instance."""
        link_id = str(uuid.uuid4())
        encrypted_data = b"test_encrypted_data"
        
        secret = Secret(
            link_id=link_id,
            encrypted_secret=encrypted_data
        )
        
        assert secret.link_id == link_id
        assert secret.encrypted_secret == encrypted_data
        assert secret.id == link_id  # id should equal link_id
        assert secret.is_e2ee is False  # default value
        assert secret.mime_type == "text/plain"  # default value
        assert isinstance(secret.created_at, datetime)
    
    def test_secret_to_dict(self):
        """Test Secret.to_dict() method."""
        link_id = str(uuid.uuid4())
        encrypted_data = b"test_encrypted_data"
        
        secret = Secret(
            link_id=link_id,
            encrypted_secret=encrypted_data,
            is_e2ee=True,
            mime_type="application/json"
        )
        
        result = secret.to_dict()
        
        assert result['id'] == link_id
        assert result['link_id'] == link_id
        assert result['is_e2ee'] is True
        assert result['mime_type'] == "application/json"
        assert 'encrypted_secret' in result
        assert 'created_at' in result
    
    def test_secret_from_dict(self):
        """Test Secret.from_dict() method."""
        link_id = str(uuid.uuid4())
        encrypted_data = b"test_encrypted_data"
        
        # Create a secret first
        original_secret = Secret(
            link_id=link_id,
            encrypted_secret=encrypted_data,
            is_e2ee=True,
            mime_type="application/json"
        )
        
        # Convert to dict and back
        secret_dict = original_secret.to_dict()
        reconstructed_secret = Secret.from_dict(secret_dict)
        
        assert reconstructed_secret.link_id == original_secret.link_id
        assert reconstructed_secret.encrypted_secret == original_secret.encrypted_secret
        assert reconstructed_secret.is_e2ee == original_secret.is_e2ee
        assert reconstructed_secret.mime_type == original_secret.mime_type
    
    def test_secret_with_e2ee_data(self):
        """Test Secret with E2EE data."""
        link_id = str(uuid.uuid4())
        encrypted_data = b"test_encrypted_data"
        e2ee_data = {
            "salt": "test_salt",
            "nonce": "test_nonce"
        }
        
        secret = Secret(
            link_id=link_id,
            encrypted_secret=encrypted_data,
            is_e2ee=True,
            e2ee_data=e2ee_data
        )
        
        assert secret.e2ee_data == e2ee_data
        
        # Test round-trip
        secret_dict = secret.to_dict()
        assert secret_dict['e2ee_data'] == e2ee_data
        
        reconstructed = Secret.from_dict(secret_dict)
        assert reconstructed.e2ee_data == e2ee_data
    
    def test_secret_repr(self):
        """Test Secret __repr__ method."""
        link_id = str(uuid.uuid4())
        encrypted_data = b"test_encrypted_data"
        
        secret = Secret(
            link_id=link_id,
            encrypted_secret=encrypted_data
        )
        
        repr_str = repr(secret)
        assert f"<Secret {link_id}>" == repr_str
    
    def test_secret_binary_data_handling(self):
        """Test that binary data is properly handled in to_dict/from_dict."""
        binary_data = bytes([0, 1, 2, 3, 255, 254, 253])  # Mix of byte values
        secret = Secret(
            link_id=str(uuid.uuid4()),
            encrypted_secret=binary_data
        )
        
        # Data should be preserved exactly
        assert secret.encrypted_secret == binary_data
        assert isinstance(secret.encrypted_secret, bytes)
        
        # Test round-trip through dict conversion
        secret_dict = secret.to_dict()
        reconstructed = Secret.from_dict(secret_dict)
        assert reconstructed.encrypted_secret == binary_data
    
    def test_secret_datetime_handling(self):
        """Test datetime handling in Secret model."""
        now = datetime.now(timezone.utc)
        secret = Secret(
            link_id=str(uuid.uuid4()),
            encrypted_secret=b"test_data",
            created_at=now
        )
        
        assert secret.created_at == now
        
        # Test round-trip through dict conversion
        secret_dict = secret.to_dict()
        reconstructed = Secret.from_dict(secret_dict)
        
        # Should be equal (within microseconds due to ISO format precision)
        time_diff = abs((reconstructed.created_at - now).total_seconds())
        assert time_diff < 0.001  # Less than 1ms difference