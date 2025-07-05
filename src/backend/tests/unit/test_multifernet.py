# backend/tests/test_multifernet.py
import pytest
import os
from unittest.mock import patch
from cryptography.fernet import Fernet
from app.encryption import encrypt_secret, decrypt_secret


class TestMultiFernetRotation:
    """Test cases for MultiFernet key rotation functionality."""

    def test_encrypt_decrypt_with_single_key(self, single_key_environment):
        """Test encryption and decryption with a single key."""
        secret = "Test secret for single key"
        
        # Encrypt with current key
        encrypted = encrypt_secret(secret)
        assert isinstance(encrypted, bytes)
        
        # Decrypt should work
        decrypted = decrypt_secret(encrypted)
        assert decrypted == secret

    def test_encrypt_decrypt_with_key_rotation(self, key_rotation_environment):
        """Test encryption and decryption during key rotation scenario."""
        secret = "Test secret for key rotation"
        
        # Encrypt with current key (first in MultiFernet list)
        encrypted = encrypt_secret(secret)
        assert isinstance(encrypted, bytes)
        
        # Decrypt should work with MultiFernet
        decrypted = decrypt_secret(encrypted)
        assert decrypted == secret

    def test_decrypt_old_secret_with_previous_key(self):
        """Test that secrets encrypted with previous key can still be decrypted."""
        # Create a secret encrypted with what would be the "previous" key
        previous_key = Fernet.generate_key()
        fernet_previous = Fernet(previous_key)
        secret = "Secret encrypted with old key"
        old_encrypted = fernet_previous.encrypt(secret.encode())
        
        # Set up environment with both keys (previous key as "previous")
        current_key = Fernet.generate_key()
        
        with patch.dict(os.environ, {
            'MASTER_ENCRYPTION_KEY': current_key.decode(),
            'MASTER_ENCRYPTION_KEY_PREVIOUS': previous_key.decode()
        }, clear=False):
            # Import after setting environment to get updated config
            import importlib
            import app.config
            import app.encryption
            # Reload modules to pick up new environment
            importlib.reload(app.config)
            importlib.reload(app.encryption)
            
            # Should be able to decrypt the old secret
            decrypted = app.encryption.decrypt_secret(old_encrypted)
            assert decrypted == secret

    def test_backward_compatibility_with_legacy_key(self):
        """Test backward compatibility when only legacy MASTER_ENCRYPTION_KEY is set."""
        legacy_key = Fernet.generate_key().decode()
        
        with patch.dict(os.environ, {
            'MASTER_ENCRYPTION_KEY': legacy_key
        }, clear=True):
            # Remove new keys
            for key in ['MASTER_ENCRYPTION_KEY_PREVIOUS']:
                if key in os.environ:
                    del os.environ[key]
                    
            # Reload config to pick up legacy key
            import importlib
            import app.config
            import app.encryption
            importlib.reload(app.config)
            importlib.reload(app.encryption)
            
            # Should work with legacy key
            secret = "Legacy key test"
            encrypted = app.encryption.encrypt_secret(secret)
            decrypted = app.encryption.decrypt_secret(encrypted)
            assert decrypted == secret
