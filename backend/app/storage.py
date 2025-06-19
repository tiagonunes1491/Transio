# backend/app/storage.py
import uuid
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

# Use your existing Config import
from config import Config

# Import the Cosmos DB client and your Secret model
from . import cosmos_client, database, container
from .models import Secret
from azure.cosmos.exceptions import CosmosResourceNotFoundError

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
    Stores the encrypted secret data in the Cosmos DB database.
    Returns a unique link ID for accessing the secret, or None if storage fails.
    """
    if not isinstance(encrypted_secret_data, bytes):
        logger.error("Encrypted secret data must be bytes.")
        raise TypeError("Encrypted secret data must be bytes.")

    if not container:
        logger.error("Cosmos DB container not initialized")
        return None

    link_id = generate_unique_link_id()
    new_secret = Secret(
        link_id=link_id,
        encrypted_secret=encrypted_secret_data,
    )

    try:
        # Store the document in Cosmos DB
        container.create_item(body=new_secret.to_dict())
        logger.info(f"Stored secret with link_id: {link_id} in Cosmos DB.")
        return link_id
    except Exception as e:
        logger.error(f"Cosmos DB error storing secret {link_id}: {e}", exc_info=True)
        return None  # Indicate failure to store


def retrieve_and_delete_secret(link_id: str) -> bytes | None:
    """
    Retrieves the encrypted secret by its link ID from the database
    and then immediately deletes it to ensure one-time access.
    Returns the encrypted secret data (bytes) or None if not found or if an error occurs.
    """
    if not link_id or not isinstance(link_id, str):
        logger.warning(
            f"Attempt to retrieve secret with invalid link_id type or empty: {link_id}"
        )
        return None

    if not container:
        logger.error("Cosmos DB container not initialized")
        return None

    try:
        # Retrieve the document by ID
        response = container.read_item(item=link_id, partition_key=link_id)
        secret_data = Secret.from_dict(response)
        
        # Get the encrypted data before deletion
        encrypted_data = secret_data.encrypted_secret

        # CRITICAL: Delete the secret immediately after retrieval for one-time access.
        container.delete_item(item=link_id, partition_key=link_id)
        logger.info(
            f"Retrieved and deleted secret with link_id: {link_id} from Cosmos DB."
        )
        return encrypted_data

    except CosmosResourceNotFoundError:
        logger.info(
            f"Secret with link_id: {link_id} not found in Cosmos DB (it may have been already accessed or never existed)."
        )
        return None
    except Exception as e:
        logger.error(
            f"Cosmos DB error retrieving/deleting secret for link_id {link_id}: {e}",
            exc_info=True,
        )
        return None


def cleanup_expired_secrets() -> int:
    """
    Cleans up secrets from the database that have expired.
    With Cosmos DB TTL, this is mostly handled automatically,
    but this function can still be used for manual cleanup.
    Returns the number of secrets removed.
    """
    removed_count = 0
    
    if not container:
        logger.error("Cosmos DB container not initialized")
        return 0
        
    try:
        now_utc = datetime.now(timezone.utc)
        expiry_threshold = now_utc - timedelta(minutes=_SECRET_EXPIRY_MINUTES)

        # Query for expired secrets
        query = f"SELECT * FROM c WHERE c.created_at < '{expiry_threshold.isoformat()}'"
        expired_items = list(container.query_items(query=query, enable_cross_partition_query=True))

        # Delete expired items
        for item in expired_items:
            try:
                container.delete_item(item=item['id'], partition_key=item['link_id'])
                removed_count += 1
            except CosmosResourceNotFoundError:
                # Item already deleted (possibly by TTL)
                pass

        if removed_count > 0:
            logger.info(
                f"Manually cleaned up {removed_count} expired secrets from Cosmos DB."
            )
        else:
            logger.info(
                "Cleanup_expired_secrets found no expired secrets to remove from Cosmos DB."
            )

        return removed_count

    except Exception as e:
        logger.error(
            f"Cosmos DB error during cleanup_expired_secrets: {e}", exc_info=True
        )
        return 0  # Return 0 on error, as per original return type expectation


def check_secret_exists(link_id: str) -> bool:
    """
    Checks if a secret with the provided link_id exists in the database.
    Returns True if found, False otherwise.
    This method does not delete the secret, it's only for checking existence.
    """
    if not link_id:
        logger.warning("Attempt to check existence of a secret with empty link_id")
        return False

    if not container:
        logger.error("Cosmos DB container not initialized")
        return False

    try:
        # Try to read the item by ID
        container.read_item(item=link_id, partition_key=link_id)
        return True

    except CosmosResourceNotFoundError:
        return False
    except Exception as e:
        logger.error(
            f"Error checking for existence of secret with link_id {link_id}: {e}",
            exc_info=True,
        )
        return False
