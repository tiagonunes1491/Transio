from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
import logging
import ssl

logger = logging.getLogger(__name__)

def init_cosmos_db(app):
    """Initialize Cosmos DB client and connect to existing database and container"""
    
    try:
        # Get configuration from app config
        endpoint = app.config.get('COSMOS_ENDPOINT')
        key = app.config.get('COSMOS_KEY')
        use_managed_identity = app.config.get('USE_MANAGED_IDENTITY', False)
        database_name = app.config.get('COSMOS_DATABASE_NAME', 'SecureSharer')
        container_name = app.config.get('COSMOS_CONTAINER_NAME', 'secrets')
        
        if not endpoint:
            logger.error("Cosmos DB endpoint not configured")
            return False
        
        # Check if we're using the local emulator (disable SSL verification for emulator)
        connection_verify = True
        if 'localhost' in endpoint or 'cosmosdb:8081' in endpoint:
            logger.info("Detected Cosmos DB emulator - disabling SSL verification")
            connection_verify = False
        
        # Initialize client with managed identity if enabled, otherwise use key
        if use_managed_identity:
            logger.info("Using managed identity for Cosmos DB authentication")
            
            # Check if a User-assigned managed identity client ID is provided
            import os
            client_id = os.environ.get('AZURE_CLIENT_ID')
            
            if client_id:
                logger.info(f"Using User-assigned managed identity with client ID: {client_id}")
                credential = DefaultAzureCredential(managed_identity_client_id=client_id)
            else:
                logger.info("No AZURE_CLIENT_ID found, using system-assigned managed identity or default credential chain")
                credential = DefaultAzureCredential()
                
            cosmos_client = CosmosClient(endpoint, credential, connection_verify=connection_verify)
        elif key:
            logger.info("Using access key for Cosmos DB authentication")
            cosmos_client = CosmosClient(endpoint, key, connection_verify=connection_verify)
        else:
            logger.error("Neither managed identity nor access key configured for Cosmos DB")
            return False
        
        # Get references to existing database and container (DO NOT CREATE)
        database = cosmos_client.get_database_client(database_name)
        container = database.get_container_client(container_name)
          # Test connectivity by trying to read container properties
        container_properties = container.read()
        logger.info(f"Connected to existing container: {container_properties['id']}")
        logger.info(f"Container TTL setting: {container_properties.get('defaultTtl', 'Not set')}")
        
        # Store the Cosmos DB objects in the app context
        app.cosmos_client = cosmos_client
        app.cosmos_database = database
        app.cosmos_container = container
        
        auth_method = "managed identity" if use_managed_identity else "access key"
        logger.info(f"Cosmos DB connection established using {auth_method}: database={database_name}, container={container_name}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to connect to Cosmos DB: {e}")
        logger.error("Make sure the database and container exist and are properly configured")
        return False

def get_cosmos_container():
    """Get the Cosmos DB container from the current Flask app"""
    from flask import current_app
    return getattr(current_app, 'cosmos_container', None)
