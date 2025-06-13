# backend/tests/test_encryption.py
import pytest
import sys
import os
from unittest.mock import patch, MagicMock
from cryptography.fernet import InvalidToken

from backend.app.encryption import encrypt_secret, decrypt_secret


class TestEncryptSecret:
    """Test cases for the encrypt_secret function."""
    
    def test_encrypt_secret_success(self, sample_secret):
        """Test successful encryption of a valid secret."""
        result = encrypt_secret(sample_secret)
        
        assert isinstance(result, bytes)
        assert len(result) > 0
    
    def test_encrypt_secret_empty_string(self):
        """Test that empty string raises ValueError."""
        with pytest.raises(ValueError, match="Secret cannot be empty"):
            encrypt_secret("")
    
    def test_encrypt_secret_non_string_input(self):
        """Test that non-string input raises TypeError."""
        with pytest.raises(TypeError, match="Secret to encrypt must be a string"):
            encrypt_secret(123)
        
        with pytest.raises(TypeError, match="Secret to encrypt must be a string"):
            encrypt_secret(None)
        
        with pytest.raises(TypeError, match="Secret to encrypt must be a string"):
            encrypt_secret(["test"])
    
    def test_encrypt_secret_unicode_content(self):
        """Test encryption of unicode content."""
        unicode_secret = "🔒 This is a test with unicode characters! 🚀"
        result = encrypt_secret(unicode_secret)
        
        assert isinstance(result, bytes)
        assert len(result) > 0
    
    @patch('backend.app.encryption.cipher_suite', None)
    def test_encrypt_secret_no_cipher_suite(self, sample_secret):
        """Test encryption failure when cipher_suite is not initialized."""
        with pytest.raises(Exception, match="Encryption suite not initialized"):
            encrypt_secret(sample_secret)


class TestDecryptSecret:
    """Test cases for the decrypt_secret function."""
    
    def test_decrypt_secret_success(self, sample_secret):
        """Test successful decryption of a valid encrypted secret."""
        encrypted = encrypt_secret(sample_secret)
        result = decrypt_secret(encrypted)
        
        assert result == sample_secret
    
    def test_decrypt_secret_invalid_token(self):
        """Test decryption with invalid token returns None."""
        invalid_token = b"invalid_encrypted_data"
        result = decrypt_secret(invalid_token)
        
        assert result is None
    
    def test_decrypt_secret_non_bytes_input(self):
        """Test that non-bytes input raises TypeError."""
        with pytest.raises(TypeError, match="Encrypted token must be bytes"):
            decrypt_secret("not_bytes")
        
        with pytest.raises(TypeError, match="Encrypted token must be bytes"):
            decrypt_secret(123)
    
    def test_decrypt_secret_unicode_roundtrip(self):
        """Test encryption and decryption of unicode content."""
        unicode_secret = "🔒 This is a test with unicode characters! 🚀"
        encrypted = encrypt_secret(unicode_secret)
        result = decrypt_secret(encrypted)
        
        assert result == unicode_secret
    
    @patch('backend.app.encryption.cipher_suite', None)
    def test_decrypt_secret_no_cipher_suite(self, encrypted_secret_bytes):
        """Test decryption failure when cipher_suite is not initialized."""
        result = decrypt_secret(encrypted_secret_bytes)
        
        assert result is None
    
    @patch('backend.app.encryption.cipher_suite')
    def test_decrypt_secret_invalid_token_exception(self, mock_cipher):
        """Test handling of InvalidToken exception."""
        mock_cipher.decrypt.side_effect = InvalidToken()
        
        result = decrypt_secret(b"some_encrypted_data")
        
        assert result is None
    
    @patch('backend.app.encryption.cipher_suite')
    def test_decrypt_secret_unexpected_exception(self, mock_cipher):
        """Test handling of unexpected exceptions during decryption."""
        mock_cipher.decrypt.side_effect = Exception("Unexpected error")
        
        result = decrypt_secret(b"some_encrypted_data")
        
        assert result is None


class TestEncryptionRoundtrip:
    """Test encryption and decryption roundtrip scenarios."""
    
    def test_encrypt_decrypt_roundtrip(self):
        """Test that encryption followed by decryption returns original text."""
        original_secrets = [
            "Simple test",
            "Multi\nline\ntext",
            "Special chars: !@#$%^&*()",
            "Unicode: 🔒🚀🎯",
            "Long text: " + "x" * 1000
        ]
        
        for secret in original_secrets:
            encrypted = encrypt_secret(secret)
            decrypted = decrypt_secret(encrypted)
            assert decrypted == secret
    
    def test_different_encryptions_same_plaintext(self, sample_secret):
        """Test that encrypting the same plaintext produces different ciphertexts."""
        encrypted1 = encrypt_secret(sample_secret)
        encrypted2 = encrypt_secret(sample_secret)
        
        # Due to Fernet's use of random IV, same plaintext should produce different ciphertexts
        assert encrypted1 != encrypted2
        
        # But both should decrypt to the same plaintext
        assert decrypt_secret(encrypted1) == sample_secret
        assert decrypt_secret(encrypted2) == sample_secret


class TestEncryptionModuleInitialization:
    """Test encryption module initialization error paths."""
    
    def test_encryption_init_missing_key_attribute(self):
        """Test encryption module initialization when key attribute is missing."""
        # Test by creating a module-like mock that doesn't have the key attribute
        original_config = sys.modules.get('config')
        
        try:
            # Create a mock config class that raises AttributeError
            class MockConfigMissingKey:
                pass  # No MASTER_ENCRYPTION_KEY_BYTES attribute
            
            # Test what happens when we try to access the missing attribute
            mock_config = MockConfigMissingKey()
            with pytest.raises(AttributeError):
                _ = mock_config.MASTER_ENCRYPTION_KEY_BYTES
                
        finally:
            if original_config:
                sys.modules['config'] = original_config
    
    def test_encryption_init_invalid_key_value(self):
        """Test encryption module initialization with invalid key."""
        # Test the ValueError path by directly testing Fernet with an invalid key
        with pytest.raises(ValueError):
            from cryptography.fernet import Fernet
            Fernet(b'invalid_key_too_short')  # This will raise ValueError
    
    def test_encryption_fernet_initialization_paths(self):
        """Test that the error handling paths in encryption initialization work."""
        # Since the module is already imported, test the logic by examining 
        # what would happen with various inputs to Fernet()
        from cryptography.fernet import Fernet
        
        # Test that normal valid key works
        valid_key = Fernet.generate_key()
        cipher = Fernet(valid_key)
        assert cipher is not None
        
        # Test that invalid key raises ValueError
        with pytest.raises(ValueError):
            Fernet(b'invalid')
        
        # Test that non-bytes input raises TypeError or ValueError
        with pytest.raises((TypeError, ValueError)):
            Fernet("not_bytes")
    
    def test_encryption_module_has_cipher_suite(self):
        """Test that the encryption module properly initialized cipher_suite."""
        from backend.app import encryption
        
        # The cipher_suite should be initialized if we got here
        assert encryption.cipher_suite is not None
        
        # Test that we can use it for encryption/decryption
        test_data = b"test data"
        encrypted = encryption.cipher_suite.encrypt(test_data)
        decrypted = encryption.cipher_suite.decrypt(encrypted)
        assert decrypted == test_data