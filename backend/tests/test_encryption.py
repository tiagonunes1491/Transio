# backend/tests/test_encryption.py
import pytest
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