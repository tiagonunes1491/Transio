# backend/app/storage.py
import uuid
import logging
from typing import Optional

# Import the get_container function
from . import get_cosmos_container
from .models import Secret
from azure.cosmos.exceptions import CosmosResourceNotFoundError

# Initialize logger for this module
logger = logging.getLogger(__name__)

def get_container():
    """Get the initialized Cosmos DB container"""
    container = get_cosmos_container()
    if container is None:
        logger.error("Container is None - Cosmos DB may not be properly initialized")
    return container


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
    
    container = get_container()
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
            f"Attempt to retrieve secret with invalid link_id type or empty: {link_id}"        )
        return None

    container = get_container()
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
    With Cosmos DB TTL enabled, expired secrets are automatically removed.
    This function is kept for compatibility but is no longer needed.
    Returns 0 as cleanup is handled automatically by Cosmos DB.
    """
    logger.info("Cleanup not needed - Cosmos DB TTL handles automatic cleanup")
    return 0


def check_secret_exists(link_id: str) -> bool:
    """
    Checks if a secret with the provided link_id exists in the database.
    Returns True if found, False otherwise.
    This method does not delete the secret, it's only for checking existence.
    """
    if not link_id:
        logger.warning("Attempt to check existence of a secret with empty link_id")
        return False

    container = get_container()
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
