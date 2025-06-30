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


def store_encrypted_secret(encrypted_secret_data: bytes, is_e2ee: bool = False, 
                          mime_type: str = "text/plain", e2ee_data: Optional[dict] = None) -> str | None:
    """
    Stores the encrypted secret data in the Cosmos DB database.
    For E2EE secrets, also stores the e2ee metadata.
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
        is_e2ee=is_e2ee,
        mime_type=mime_type,
        e2ee_data=e2ee_data,
    )

    try:
        # Store the document in Cosmos DB
        container.create_item(body=new_secret.to_dict())
        logger.info(f"Stored secret with link_id: {link_id} in Cosmos DB.")
        return link_id
    except Exception as e:
        logger.error(f"Cosmos DB error storing secret {link_id}: {e}", exc_info=True)
        return None  # Indicate failure to store


def retrieve_secret(link_id: str) -> Secret | None:
    """
    Retrieves the secret by its link ID from the database.
    Does not delete the secret - use delete_secret() for that.
    Returns the Secret object with all metadata, or None if not found or if an error occurs.
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
        logger.info(f"Retrieved secret with link_id: {link_id} from Cosmos DB.")
        return secret_data

    except CosmosResourceNotFoundError:
        logger.info(
            f"Secret with link_id: {link_id} not found in Cosmos DB (it may have been already accessed or never existed)."
        )
        return None
    except Exception as e:
        logger.error(
            f"Cosmos DB error retrieving secret for link_id {link_id}: {e}",
            exc_info=True,
        )
        return None


def delete_secret(link_id: str) -> bool:
    """
    Deletes the secret by its link ID from the database.
    Returns True if successfully deleted, False otherwise.
    """
    if not link_id or not isinstance(link_id, str):
        logger.warning(
            f"Attempt to delete secret with invalid link_id type or empty: {link_id}"
        )
        return False

    container = get_container()
    if not container:
        logger.error("Cosmos DB container not initialized")
        return False

    try:
        container.delete_item(item=link_id, partition_key=link_id)
        logger.info(f"Deleted secret with link_id: {link_id} from Cosmos DB.")
        return True

    except CosmosResourceNotFoundError:
        logger.info(
            f"Secret with link_id: {link_id} not found for deletion (it may have been already deleted or never existed)."
        )
        return False
    except Exception as e:
        logger.error(
            f"Cosmos DB error deleting secret for link_id {link_id}: {e}",
            exc_info=True,
        )
        return False


def retrieve_and_delete_secret(link_id: str) -> Secret | None:
    """
    Retrieves the secret and automatically deletes it for traditional (non-E2EE) secrets.
    For E2EE secrets, only retrieves (caller must handle deletion separately).
    Returns the Secret object with all metadata, or None if not found or if an error occurs.
    """
    secret_obj = retrieve_secret(link_id)
    
    if secret_obj and not secret_obj.is_e2ee:
        # Traditional secret - delete immediately for one-time access
        if delete_secret(link_id):
            logger.info(f"Traditional secret {link_id} retrieved and deleted for one-time access.")
        else:
            logger.warning(f"Failed to delete traditional secret {link_id} after retrieval.")
    elif secret_obj and secret_obj.is_e2ee:
        # E2EE secret - don't auto-delete, let caller handle it
        logger.info(f"E2EE secret {link_id} retrieved (not auto-deleted).")
    
    return secret_obj


