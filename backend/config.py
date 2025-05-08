# backend/config.py
import os
import logging
from dotenv import load_dotenv
from cryptography.fernet import Fernet

# Configure basic logging
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

# Load environment variables from .env file in the current directory (backend/)
# This should be called as early as possible,
# and before importing any module that depends on environment variables
dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path)
else:
    # This is a fallback for environments where .env might not be present
    # (e.g., production if variables are set directly)
    # but for local dev, .env is expected.
    logging.warning(f".env file not found at {dotenv_path}. "
                    "Ensure MASTER_ENCRYPTION_KEY is set via environment variables if .env is not used.")

class Config:
    MASTER_ENCRYPTION_KEY = os.getenv("MASTER_ENCRYPTION_KEY")
    FLASK_APP = os.getenv("FLASK_APP", "app/main.py") # Default value if not in .env
    FLASK_DEBUG = os.getenv("FLASK_DEBUG", "True").lower() in ('true', '1', 't') # Default to True, handle string 'True'
    # Add MAX_SECRET_LENGTH, defaulting to 100KB if not set in .env
    MAX_SECRET_LENGTH_KB = int(os.getenv("MAX_SECRET_LENGTH_KB", "100"))
    MAX_SECRET_LENGTH_BYTES = MAX_SECRET_LENGTH_KB * 1024

    if not MASTER_ENCRYPTION_KEY:
        # Fail fast - encryption key is required for this security application
        raise ValueError("MASTER_ENCRYPTION_KEY not set. Please set it in .env file or environment.")
    
    # Ensure the key is bytes for Fernet and validate it's a proper Fernet key
    try:
        MASTER_ENCRYPTION_KEY_BYTES = MASTER_ENCRYPTION_KEY.encode('utf-8')
        # Test if it's a valid Fernet key by attempting to initialize a Fernet instance
        Fernet(MASTER_ENCRYPTION_KEY_BYTES)  # This will raise if invalid
    except Exception as e:
        # Log the error and re-raise with a clearer message
        logging.error(f"Invalid MASTER_ENCRYPTION_KEY: {e}")
        raise ValueError(f"Invalid MASTER_ENCRYPTION_KEY: {e}")

# You can add other configuration variables here as needed