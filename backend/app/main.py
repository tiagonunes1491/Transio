# backend/app/main.py
from flask import Flask, request, jsonify, current_app
from flask_cors import CORS

## Trigger CI v3

# Relative imports for modules within the same package ('app')
from . import db  # ADD THIS LINE - db is now from app/__init__.py
from .encryption import encrypt_secret, decrypt_secret
from .storage import (
    store_encrypted_secret,
    retrieve_and_delete_secret,
    check_secret_exists,
)

# Relative import for config from the parent directory ('backend')
from ..config import Config

# Initialize Flask App
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes (for development purposes)

# Load configuration from config.py (which loads .env)
app.config.from_object(Config)
db.init_app(app)  # Initialize the imported db instance

with app.app_context():  # <-- CREATE TABLES
    db.create_all()  # Use the imported db instance
    print("Database tables created or already exist.")


@app.route("/api/share", methods=["POST"])
def share_secret_api():
    """API endpoint to share a new secret."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400

    data = request.get_json()
    secret_text = data.get("secret")

    if not secret_text:
        return jsonify({"error": "Missing 'secret' field in JSON payload"}), 400

    if not isinstance(secret_text, str):
        return jsonify({"error": "'secret' must be a string"}), 400

    # Basic input validation: length check
    # Use MAX_SECRET_LENGTH_BYTES from app config
    if (
        len(secret_text.encode("utf-8")) > current_app.config["MAX_SECRET_LENGTH_BYTES"]
    ):  # Check byte length
        return jsonify(
            {
                "error": f"Secret exceeds maximum length of {current_app.config['MAX_SECRET_LENGTH_BYTES'] // 1024}KB"
            }
        ), 413  # Payload Too Large

    try:
        encrypted_data = encrypt_secret(secret_text)
        link_id = store_encrypted_secret(encrypted_data)
        # The API returns the ID. The frontend will construct the full access URL.
        # Example: http://yourdomain/view/LINK_ID (where /view/ is a frontend route)
        # Or for direct API access: http://yourdomain/api/share/secret/LINK_ID
        current_app.logger.info(f"Secret stored successfully with link_id: {link_id}")
        return jsonify(
            {
                "link_id": link_id,
                "message": "Secret stored. Use this ID to create your access link.",
            }
        ), 201
    except (
        ValueError
    ) as ve:  # Catch specific errors like empty secret from encryption/storage
        current_app.logger.warning(f"ValueError during secret sharing: {ve}")
        return jsonify({"error": "Invalid input provided."}), 400
    except TypeError as te:  # Catch type errors from encryption/storage
        current_app.logger.warning(f"TypeError during secret sharing: {te}")
        return jsonify({"error": str(te)}), 400
    except Exception as e:
        # Log the full exception for debugging on the server.
        current_app.logger.error(f"Error sharing secret: {e}", exc_info=True)
        # Return a generic error message to the client.
        return jsonify(
            {"error": "Failed to store secret due to an internal server error."}
        ), 500


@app.route("/api/share/secret/<link_id>", methods=["GET", "HEAD"])
def retrieve_secret_api(link_id):
    """API endpoint to retrieve (and delete) a secret."""
    if not link_id:  # Should be caught by routing rules, but defensive check.
        current_app.logger.warning("Attempt to retrieve secret with empty link_id.")
        return (
            jsonify({"error": "Secret ID is required"}),
            404,
        )  # For HEAD requests, we only check if the secret exists without retrieving/deleting it
    if request.method == "HEAD":
        exists = check_secret_exists(link_id)
        if exists:
            return "", 200
        else:
            return "", 404

    encrypted_data = retrieve_and_delete_secret(link_id)

    if encrypted_data:
        decrypted_secret = decrypt_secret(encrypted_data)
        if decrypted_secret is not None:
            # Secret successfully decrypted. Return it as JSON once.
            # Data is already deleted from the store by retrieve_and_delete_secret.
            current_app.logger.info(f"Secret {link_id} retrieved and returned as JSON.")
            return jsonify({"secret": decrypted_secret}), 200
        else:
            # This case means decryption failed (e.g., key mismatch, corrupted data, or InvalidToken).
            # This should be a rare and serious issue if the key hasn't changed and data was intact.
            # storage.py or encryption.py would have logged details.
            current_app.logger.error(
                f"Failed to decrypt secret for link_id: {link_id}. Data may be corrupt, key mismatch, or token was invalid."
            )
            # For security, don't reveal too much.
            return jsonify(
                {
                    "error": "Could not decrypt the secret. It may be corrupted or the link is invalid."
                }
            ), 500
    else:
        # Secret not found (already viewed, expired, or invalid link_id).
        # storage.py would have logged details if it was an attempted retrieval of a non-existent ID.
        current_app.logger.info(
            f"Secret {link_id} not found for retrieval (already viewed, expired, or invalid)."
        )
        return jsonify(
            {
                "error": "Secret not found. It may have been already viewed, expired, or the link is invalid."
            }
        ), 404


@app.route("/health", methods=["GET"])
def health_check():
    """Basic health check endpoint for monitoring."""
    return jsonify({"status": "healthy", "message": "Backend is running."}), 200


# This block allows running the app directly with `python backend/app/main.py`
# For development. For production, use a WSGI server like Gunicorn or Waitress.
if __name__ == "__main__":
    # The critical check for MASTER_ENCRYPTION_KEY_BYTES happens when encryption.py is imported.
    # If the key is missing or invalid, encryption.py will raise SystemExit.
    # So, if we reach here, the key was at least present and Fernet could be initialized.
    print("Attempting to start Flask development server...")
    print(f"Debug mode is: {app.debug}")
    print(f"Flask app name: {app.name}")
    print(
        f"Master key loaded and Fernet initialized: {'Yes (assuming no SystemExit from encryption.py)' if Config.MASTER_ENCRYPTION_KEY_BYTES else 'NO - CRITICAL (check logs)'}"
    )

    if not Config.MASTER_ENCRYPTION_KEY_BYTES:
        print(
            "CRITICAL: Master encryption key bytes are not available in Config. The application will not function correctly."
        )
        print(
            "Please check .env file and ensure MASTER_ENCRYPTION_KEY is set and valid."
        )
    else:
        # Run the Flask development server
        # Host 0.0.0.0 makes it accessible from other devices on the network
        app.run(host="0.0.0.0", port=5000)
