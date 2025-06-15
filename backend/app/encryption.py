# backend/app/encryption.py
# 2 Trigger
import logging
from cryptography.fernet import Fernet, InvalidToken
from config import Config

# Initialize logger for this module
logger = logging.getLogger(__name__)

# Initialize Fernet with the master key from config
cipher_suite = None

try:
    # Initialize the Fernet cipher suite with the key from configuration
    cipher_suite = Fernet(Config.MASTER_ENCRYPTION_KEY_BYTES)
    logger.info("Encryption suite initialized successfully.")
except AttributeError:
    # This happens if MASTER_ENCRYPTION_KEY_BYTES doesn't exist in Config
    logger.critical("Encryption key (MASTER_ENCRYPTION_KEY_BYTES) is not initialized in config.")
    raise SystemExit("Failed to initialize encryption suite: Master encryption key is missing.")
except ValueError as ve:
    # This error occurs if the key is not a valid Fernet key
    logger.critical(f"Error initializing Fernet cipher due to an invalid key: {ve}")
    raise SystemExit(f"Failed to initialize encryption suite: Invalid master key ({ve}).")
except Exception as e:
    # Catch any other unexpected errors during Fernet initialization
    logger.critical(f"An unexpected error occurred during Fernet initialization: {e}")
    raise SystemExit("Failed to initialize encryption suite due to an unexpected error with the master key.")


def encrypt_secret(secret_text: str) -> bytes:
    """Encrypts a text secret."""
    if not cipher_suite: # Should not happen if SystemExit was raised, but as a safeguard
        logger.critical("Attempted to use encrypt_secret but cipher_suite is not initialized.") # Changed from raise Exception
        raise Exception("Encryption suite not initialized.") # Or handle more gracefully depending on desired behavior
    if not isinstance(secret_text, str):
        logger.error("Type error in encrypt_secret: secret_text must be a string.")
        raise TypeError("Secret to encrypt must be a string.")
    if not secret_text:
        logger.warning("Attempted to encrypt an empty secret.")
        raise ValueError("Secret cannot be empty.")

    encoded_text = secret_text.encode('utf-8') # Encode string to bytes
    encrypted_text = cipher_suite.encrypt(encoded_text)
    return encrypted_text

def decrypt_secret(encrypted_token: bytes) -> str | None:
    """
    Decrypts an encrypted token back to text.
    Returns None if decryption fails (e.g., invalid token, wrong key, corrupted data).
    """
    if not cipher_suite: # Safeguard
        logger.critical("CRITICAL: Decryption attempted but encryption suite is not initialized.")
        return None # Or raise a more specific internal server error if this path is reachable

    if not isinstance(encrypted_token, bytes):
        logger.error("Error: Encrypted token for decryption must be bytes.")
        raise TypeError("Encrypted token must be bytes.")

    try:
        decrypted_text_bytes = cipher_suite.decrypt(encrypted_token)
        return decrypted_text_bytes.decode('utf-8') # Decode bytes back to string
    except InvalidToken:
        # This is an expected exception if the token is tampered with, incorrect,
        # or if the wrong key was used (e.g., key changed after encryption).
        # For security, log this attempt but don't reveal specifics to the client.
        logger.warning("Decryption failed: Invalid token or key. This could indicate tampering or an old link.")
        return None
    except Exception as e:
        # Catch any other potential decryption errors (e.g., issues not covered by InvalidToken)
        logger.error(f"An unexpected error occurred during decryption: {e}", exc_info=True) # Add exc_info for traceback
        return None