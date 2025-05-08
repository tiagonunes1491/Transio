# backend/app/storage.py
import uuid
import logging
from datetime import datetime, timedelta, timezone
from config import Config  # Changed from 'from backend.config import Config'

# Initialize logger for this module
logger = logging.getLogger(__name__)

# In-memory store: dictionary to hold secrets
# Format: {link_id: {"encrypted_secret": data_bytes, "created_at": timestamp}}
# WARNING: This is for initial local development ONLY. All data is lost when the app restarts.
_secrets_store = {}

# Get configuration from Config class with a default fallback
_SECRET_EXPIRY_MINUTES = getattr(Config, 'SECRET_EXPIRY_MINUTES', 60)

def generate_unique_link_id() -> str:
    """Generates a cryptographically strong unique ID for the secret link."""
    return str(uuid.uuid4())

def store_encrypted_secret(encrypted_secret_data: bytes) -> str:
    """
    Stores the encrypted secret data in the in-memory store.
    Returns a unique link ID for accessing the secret.
    """
    if not isinstance(encrypted_secret_data, bytes):
        # Ensuring that we are indeed storing bytes, as returned by the encryption function.
        logger.error("Encrypted secret data must be bytes")
        raise TypeError("Encrypted secret data must be bytes.")

    link_id = generate_unique_link_id()
    _secrets_store[link_id] = {
        "encrypted_secret": encrypted_secret_data,
        "created_at": datetime.now(timezone.utc)  # Store creation time (UTC)
    }
    logger.info(f"Stored secret with link_id: {link_id}")
    return link_id

def retrieve_and_delete_secret(link_id: str) -> bytes | None:
    """
    Retrieves the encrypted secret by its link ID and then immediately deletes it
    to ensure one-time access.
    Returns the encrypted secret data (bytes) or None if not found or expired.
    """
    if not link_id or not isinstance(link_id, str):
        logger.warning(f"Attempt to retrieve secret with invalid link_id type or empty: {link_id}")
        return None

    try:
        secret_entry = _secrets_store.get(link_id)
        
        if not secret_entry:
            logger.info(f"Secret with link_id: {link_id} not found (it may have been already accessed or never existed).")
            return None
            
        # Optional: Check for expiry before retrieval - uncomment to enable
        # expiry_time = secret_entry["created_at"] + timedelta(minutes=_SECRET_EXPIRY_MINUTES)
        # if datetime.now(timezone.utc) > expiry_time:
        #     logger.info(f"Secret {link_id} expired and was not accessed. Deleting.")
        #     del _secrets_store[link_id]
        #     return None

        encrypted_data = secret_entry["encrypted_secret"]
        # CRITICAL: Delete the secret immediately after retrieval for one-time access.
        del _secrets_store[link_id]
        logger.info(f"Retrieved and deleted secret with link_id: {link_id}")
        return encrypted_data
        
    except Exception as e:
        logger.error(f"Error retrieving secret with link_id {link_id}: {e}")
        return None

def cleanup_expired_secrets() -> int:
    """
    Periodically cleans up secrets that were stored but never accessed
    and have passed their expiry time.
    Returns the number of secrets removed.
    """
    try:
        now = datetime.now(timezone.utc)
        # Use list comprehension to get expired IDs (more pythonic)
        expired_ids = [
            link_id for link_id, data in list(_secrets_store.items())
            if now > data["created_at"] + timedelta(minutes=_SECRET_EXPIRY_MINUTES)
        ]

        if not expired_ids:
            logger.info("Cleanup found no expired secrets to remove.")
            return 0

        # Use a more concise loop to remove expired secrets
        for link_id in expired_ids:
            _secrets_store.pop(link_id, None)  # More pythonic than checking and deleting
            logger.info(f"Cleaned up expired (unaccessed) secret: {link_id}")
            
        logger.info(f"Cleanup finished. Removed {len(expired_ids)} items.")
        return len(expired_ids)
        
    except Exception as e:
        logger.error(f"Error during cleanup of expired secrets: {e}")
        return 0