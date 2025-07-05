# backend/config.py
import os
import logging
from dotenv import load_dotenv
from cryptography.fernet import Fernet

# Configure basic logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

# Load environment variables from .env file in the current directory (backend/)
# This should be called as early as possible,
# and before importing any module that depends on environment variables
dotenv_path = os.path.join(os.path.dirname(__file__), ".env")
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path)
else:
    # This is a fallback for environments where .env might not be present
    # (e.g., production if variables are set directly)
    # but for local dev, .env is expected.
    logging.warning(
        f".env file not found at {dotenv_path}. "
        "Ensure MASTER_ENCRYPTION_KEY is set via environment variables if .env is not used."
    )


class Config:
    MASTER_ENCRYPTION_KEY = os.getenv("MASTER_ENCRYPTION_KEY")
    MASTER_ENCRYPTION_KEY_PREVIOUS = os.getenv("MASTER_ENCRYPTION_KEY_PREVIOUS")
    
    FLASK_APP = os.getenv("FLASK_APP", "app/main.py")  # Default value if not in .env
    FLASK_DEBUG = os.getenv("FLASK_DEBUG", "True").lower() in (
        "true",
        "1",
        "t",
    )  # Default to True, handle string 'True'
    # Add MAX_SECRET_LENGTH, defaulting to 100KB if not set in .env
    MAX_SECRET_LENGTH_KB = int(os.getenv("MAX_SECRET_LENGTH_KB", "100"))
    MAX_SECRET_LENGTH_BYTES = MAX_SECRET_LENGTH_KB * 1024

    # --- Cosmos DB Configuration ---
    COSMOS_ENDPOINT = os.getenv("COSMOS_ENDPOINT")
    COSMOS_KEY = os.getenv("COSMOS_KEY")  # Optional - will use managed identity if not provided
    COSMOS_DATABASE_NAME = os.getenv("COSMOS_DATABASE_NAME", "SecureSharer")
    COSMOS_CONTAINER_NAME = os.getenv("COSMOS_CONTAINER_NAME", "secrets")
    
    # Use managed identity for authentication (prefer this for production)
    USE_MANAGED_IDENTITY = os.getenv("USE_MANAGED_IDENTITY", "false").lower() in ("true", "1", "t")

    # Validate Cosmos DB configuration
    if not COSMOS_ENDPOINT:
        logging.warning("COSMOS_ENDPOINT not set. Using default local emulator endpoint.")
        COSMOS_ENDPOINT = "https://localhost:8081"
    
    # For local development, default to emulator key if no managed identity and no key provided
    if not COSMOS_KEY and not USE_MANAGED_IDENTITY and COSMOS_ENDPOINT == "https://localhost:8081":
        logging.warning("COSMOS_KEY not set and managed identity not enabled. Using default local emulator key.")
        # This is the well-known emulator key for local development
        COSMOS_KEY = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=="

    # Legacy database configuration (keeping for backward compatibility during migration)
    # This will be removed after full migration    SQLALCHEMY_DATABASE_URI = os.getenv("DATABASE_URL")
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    if not MASTER_ENCRYPTION_KEY:
        # Fail fast - encryption key is required for this security application
        raise ValueError(
            "MASTER_ENCRYPTION_KEY not set. Please set it in .env file or environment."
        )

    # Collect all available keys for MultiFernet
    encryption_keys = []
    
    # Ensure the current key is bytes for Fernet and validate it's a proper Fernet key
    try:
        current_key_bytes = MASTER_ENCRYPTION_KEY.encode("utf-8")
        # Test if it's a valid Fernet key by attempting to initialize a Fernet instance
        Fernet(current_key_bytes)  # This will raise if invalid
        encryption_keys.append(current_key_bytes)
    except Exception as e:
        # Log the error and re-raise with a clearer message
        logging.error(f"Invalid MASTER_ENCRYPTION_KEY: {e}")
        raise ValueError(f"Invalid MASTER_ENCRYPTION_KEY: {e}")
    
    # Add previous key if available
    if MASTER_ENCRYPTION_KEY_PREVIOUS:
        try:
            previous_key_bytes = MASTER_ENCRYPTION_KEY_PREVIOUS.encode("utf-8")
            # Test if it's a valid Fernet key
            Fernet(previous_key_bytes)  # This will raise if invalid
            encryption_keys.append(previous_key_bytes)
            logging.info("Previous encryption key loaded successfully for key rotation support.")
        except Exception as e:
            # Log the error but don't fail - previous key is optional
            logging.warning(f"Invalid MASTER_ENCRYPTION_KEY_PREVIOUS (ignoring): {e}")
    
    # Store the validated keys for use by encryption module
    MASTER_ENCRYPTION_KEYS = encryption_keys


# You can add other configuration variables here as needed
