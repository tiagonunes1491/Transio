# backend/app/storage.py
import uuid
import logging
from datetime import datetime, timedelta, timezone

# Use your existing Config import
from config import Config

# Import the db session and your Secret model
from . import db  # Import from the package, not from main
from .models import Secret

# Initialize logger for this module, as per your existing style
logger = logging.getLogger(__name__)

# Get SECRET_EXPIRY_MINUTES from Config
# This will now be fetched from the Config class which reads from environment/.env
_SECRET_EXPIRY_MINUTES = Config.SECRET_EXPIRY_MINUTES


def generate_unique_link_id() -> str:
    """Generates a cryptographically strong unique ID for the secret link."""
    return str(uuid.uuid4())


def store_encrypted_secret(encrypted_secret_data: bytes) -> str | None:
    """
    Stores the encrypted secret data in the PostgreSQL database.
    Returns a unique link ID for accessing the secret, or None if storage fails.
    """
    if not isinstance(encrypted_secret_data, bytes):
        logger.error("Encrypted secret data must be bytes.")
        # Consistent with original raising TypeError, but for DB ops, returning None for failure is common.
        # If you prefer to always raise an exception here, you can.
        raise TypeError("Encrypted secret data must be bytes.")

    link_id = generate_unique_link_id()
    new_secret = Secret(
        link_id=link_id,
        encrypted_secret=encrypted_secret_data
        # created_at is handled by the model's default
    )

    try:
        db.session.add(new_secret)
        db.session.commit()
        logger.info(f"Stored secret with link_id: {link_id} in database.")
        return link_id
    except Exception as e:
        db.session.rollback()  # Rollback in case of database error
        logger.error(f"Database error storing secret {link_id}: {e}", exc_info=True)
        return None  # Indicate failure to store


def retrieve_and_delete_secret(link_id: str) -> bytes | None:
    """
    Retrieves the encrypted secret by its link ID from the database
    and then immediately deletes it to ensure one-time access.
    Returns the encrypted secret data (bytes) or None if not found or if an error occurs.
    """
    if not link_id or not isinstance(link_id, str):
        logger.warning(f"Attempt to retrieve secret with invalid link_id type or empty: {link_id}")
        return None

    try:
        secret_entry = db.session.query(Secret).filter_by(link_id=link_id).first()

        if not secret_entry:
            logger.info(f"Secret with link_id: {link_id} not found in database (it may have been already accessed or never existed).")
            return None

        encrypted_data = secret_entry.encrypted_secret

        # CRITICAL: Delete the secret immediately after retrieval for one-time access.
        db.session.delete(secret_entry)
        db.session.commit()
        logger.info(f"Retrieved and deleted secret with link_id: {link_id} from database.")
        return encrypted_data

    except Exception as e:
        db.session.rollback()  # Rollback in case of database error
        logger.error(f"Database error retrieving/deleting secret for link_id {link_id}: {e}", exc_info=True)
        return None


def cleanup_expired_secrets() -> int:
    """
    Periodically cleans up secrets from the database that were stored but never accessed
    and have passed their expiry time (_SECRET_EXPIRY_MINUTES).
    Returns the number of secrets removed.
    """
    removed_count = 0
    try:
        now_utc = datetime.now(timezone.utc)
        expiry_threshold = now_utc - timedelta(minutes=_SECRET_EXPIRY_MINUTES)

        # Efficiently delete expired secrets and get the count of deleted rows.
        # The delete() method on a query returns the number of rows deleted.
        num_deleted = db.session.query(Secret).filter(Secret.created_at < expiry_threshold).delete(synchronize_session='fetch')
        # synchronize_session='fetch' or False can be used. 'fetch' tries to update the session.
        # False is often simpler for bulk deletes if you don't need the session to be aware of specific instances deleted.
        
        db.session.commit()
        removed_count = num_deleted

        if removed_count > 0:
            logger.info(f"Cleaned up {removed_count} expired (unaccessed) secrets from the database.")
        else:
            logger.info("Cleanup_expired_secrets found no expired secrets to remove from the database.")
        
        return removed_count
        
    except Exception as e:
        db.session.rollback()
        logger.error(f"Database error during cleanup_expired_secrets: {e}", exc_info=True)
        return 0 # Return 0 on error, as per original return type expectation


def check_secret_exists(link_id: str) -> bool:
    """
    Checks if a secret with the provided link_id exists in the database.
    Returns True if found, False otherwise.
    This method does not delete the secret, it's only for checking existence.
    """
    if not link_id:
        logger.warning("Attempt to check existence of a secret with empty link_id")
        return False
    
    try:
        # Check if there's an unexpired secret with this link_id
        current_time = datetime.now(timezone.utc)
        expiry_time = current_time - timedelta(minutes=_SECRET_EXPIRY_MINUTES)
        
        # Query for unexpired secret with matching link_id
        secret = Secret.query.filter(
            Secret.link_id == link_id,
            Secret.created_at > expiry_time
        ).first()
        
        return secret is not None
    
    except Exception as e:
        logger.error(f"Error checking for existence of secret with link_id {link_id}: {e}", exc_info=True)
        return False