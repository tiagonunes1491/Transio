# backend/app/main.py
from flask import Flask, request, jsonify, current_app
from flask_cors import CORS

## Trigger CI v3

# Relative imports for modules within the same package ('app')
from . import init_cosmos_db  # Import Cosmos DB initialization
from .encryption import encrypt_secret, decrypt_secret
from .storage import (
    store_encrypted_secret,
    retrieve_secret,
    delete_secret,
)

# Relative import for config from the parent directory ('backend')
from ..config import Config

# Initialize Flask App
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes (for development purposes)

# Load configuration from config.py (which loads .env)
app.config.from_object(Config)

# Initialize Cosmos DB
with app.app_context():
    if init_cosmos_db(app):
        print("Cosmos DB initialized successfully.")
    else:
        print("Failed to initialize Cosmos DB. Check configuration.")
        exit(1)


@app.route("/api/share", methods=["POST"])
def share_secret_api():
    """API endpoint to share a secret with optional E2EE."""
    if not request.is_json:
        return jsonify({"error": "Request must be JSON"}), 400

    data = request.get_json()
    mime_type = data.get("mime", "text/plain")
    payload = data.get("payload")
    e2ee_data = data.get("e2ee")

    # Validate required fields
    if not payload:
        return jsonify({"error": "Missing 'payload' field in JSON"}), 400

    if not isinstance(payload, str):
        return jsonify({"error": "'payload' must be a string"}), 400

    if not isinstance(mime_type, str):
        return jsonify({"error": "'mime' must be a string"}), 400

    # Determine if this is E2EE mode
    is_e2ee = e2ee_data is not None

    if is_e2ee:
        # E2EE mode - validate e2ee structure
        if not isinstance(e2ee_data, dict):
            return jsonify({"error": "'e2ee' must be an object"}), 400
        
        required_e2ee_fields = ["salt", "nonce"]
        for field in required_e2ee_fields:
            if field not in e2ee_data:
                return jsonify({"error": f"Missing 'e2ee.{field}' field"}), 400
            if not isinstance(e2ee_data[field], str):
                return jsonify({"error": f"'e2ee.{field}' must be a string"}), 400

        # In E2EE mode, we store the encrypted payload from the main payload field
        data_to_store = payload
        current_app.logger.info("Storing E2EE encrypted secret")
    else:
        # Traditional mode - server-side encrypt the payload
        data_to_store = payload
        current_app.logger.info("Storing secret with server-side encryption")

    # Basic input validation: length check
    if len(data_to_store.encode("utf-8")) > current_app.config["MAX_SECRET_LENGTH_BYTES"]:
        return jsonify(
            {
                "error": f"Secret exceeds maximum length of {current_app.config['MAX_SECRET_LENGTH_BYTES'] // 1024}KB"
            }
        ), 413

    try:
        if is_e2ee:
            # Store E2EE encrypted data as-is (no additional server encryption)
            processed_data = data_to_store.encode('utf-8')
            link_id = store_encrypted_secret(
                processed_data, 
                is_e2ee=True, 
                mime_type=mime_type, 
                e2ee_data=e2ee_data
            )
        else:
            # Apply server-side encryption
            processed_data = encrypt_secret(data_to_store)
            link_id = store_encrypted_secret(
                processed_data, 
                is_e2ee=False, 
                mime_type=mime_type
            )
        current_app.logger.info(f"Secret stored successfully with link_id: {link_id}, e2ee: {is_e2ee}")
        
        return jsonify(
            {
                "link_id": link_id,
                "e2ee": is_e2ee,
                "mime": mime_type,
                "message": "Secret stored successfully.",
            }
        ), 201

    except (ValueError, TypeError) as e:
        current_app.logger.warning(f"Input validation error during secret storage: {e}")
        return jsonify({"error": "Invalid input provided."}), 400
    except Exception as e:
        current_app.logger.error(f"Error storing secret: {e}", exc_info=True)
        return jsonify(
            {"error": "Failed to store secret due to an internal server error."}
        ), 500


@app.route("/api/share/secret/<link_id>", methods=["GET"])
def retrieve_secret_api(link_id):
    """API endpoint to retrieve (and delete) a secret."""
    if not link_id:  # Should be caught by routing rules, but defensive check.
        current_app.logger.warning("Attempt to retrieve secret with empty link_id.")
        return (
            jsonify({"error": "Secret ID is required"}),
            404,
        )

    def pad_response_data(response_data: dict) -> dict:
        """
        Pad response data to a consistent size to prevent enumeration attacks.
        Uses the maximum secret length as reference for padding calculations.
        """
        import json
        import secrets
        
        # Calculate current response size
        current_size = len(json.dumps(response_data, separators=(',', ':')).encode('utf-8'))
        
        # Target size based on maximum possible response (roughly 150KB to account for metadata)
        # This ensures all responses are similar in size regardless of actual content
        target_size = current_app.config["MAX_SECRET_LENGTH_BYTES"] + (50 * 1024)  # 150KB total
        
        if current_size < target_size:
            # Add padding field with random data to reach target size
            padding_needed = target_size - current_size - 50  # Reserve space for padding field structure
            if padding_needed > 0:
                # Generate random padding data
                padding_data = secrets.token_urlsafe(padding_needed)[:padding_needed]
                response_data["_padding"] = padding_data
        
        return response_data

    secret_obj = retrieve_secret(link_id)

    if secret_obj:
        if secret_obj.is_e2ee:
            # E2EE secret - return encrypted payload and salt/nonce for client-side decryption
            response_data = {
                "mime": secret_obj.mime_type,
                "payload": secret_obj.encrypted_secret.decode('utf-8'),  # The encrypted text from e2ee.payload
                "e2ee": {
                    "salt": secret_obj.e2ee_data["salt"],
                    "nonce": secret_obj.e2ee_data["nonce"]
                }
            }
            
            # Delete the secret immediately (one-time access for E2EE too)
            if delete_secret(link_id):
                current_app.logger.info(f"E2EE secret {link_id} retrieved and deleted (one-time access).")
            else:
                current_app.logger.warning(f"E2EE secret {link_id} retrieved but failed to delete.")
            
            # Pad response to consistent size
            padded_response = pad_response_data(response_data)
            return jsonify(padded_response), 200
        else:
            # Traditional secret - decrypt on server and delete immediately for one-time access
            decrypted_secret = decrypt_secret(secret_obj.encrypted_secret)
            if decrypted_secret is not None:
                # Successfully decrypted - delete the secret now
                if delete_secret(link_id):
                    current_app.logger.info(f"Traditional secret {link_id} retrieved, decrypted, and deleted.")
                else:
                    current_app.logger.warning(f"Traditional secret {link_id} decrypted but failed to delete.")
                
                response_data = {
                    "mime": secret_obj.mime_type,
                    "payload": decrypted_secret
                }
                
                # Pad response to consistent size
                padded_response = pad_response_data(response_data)
                return jsonify(padded_response), 200
            else:
                # Decryption failed - delete the corrupted secret anyway
                delete_secret(link_id)
                current_app.logger.error(
                    f"Failed to decrypt secret for link_id: {link_id}. Secret deleted due to corruption."
                )
                # Return padded empty JSON with 200 to prevent enumeration
                padded_response = pad_response_data({})
                return jsonify(padded_response), 200
    else:
        # Secret not found - return dummy E2EE data to prevent enumeration attacks
        import secrets
        import base64
        import time
        import random
        
        # Add random delay (5-25ms) to simulate Cosmos DB interaction and prevent timing attacks
        delay_ms = random.uniform(5, 25)
        time.sleep(delay_ms / 1000.0)  # Convert to seconds
        
        # Generate realistic-looking dummy data with sizes similar to real secrets
        # Use a realistic size for dummy payload (between 100-1000 bytes to mimic real secrets)
        dummy_payload_size = random.randint(100, 1000)
        dummy_salt = base64.urlsafe_b64encode(secrets.token_bytes(16)).decode('utf-8').rstrip('=')
        dummy_nonce = base64.urlsafe_b64encode(secrets.token_bytes(12)).decode('utf-8').rstrip('=')
        dummy_payload = base64.urlsafe_b64encode(secrets.token_bytes(dummy_payload_size)).decode('utf-8').rstrip('=')
        
        dummy_response = {
            "mime": "text/plain",
            "payload": "Dummy payload for non-existent secret",
            "e2ee": {
                "payload": dummy_payload,
                "salt": dummy_salt,
                "nonce": dummy_nonce
            }
        }
        
        # Pad dummy response to same size as real responses
        padded_dummy_response = pad_response_data(dummy_response)
        
        current_app.logger.info(
            f"Secret {link_id} not found - returned padded dummy E2EE data to prevent enumeration (delayed {delay_ms:.1f}ms)."
        )
        return jsonify(padded_dummy_response), 200


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
