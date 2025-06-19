from azure.cosmos import CosmosClient, PartitionKey
from azure.identity import DefaultAzureCredential
import logging

# Cosmos DB client instance
cosmos_client = None
database = None
container = None

logger = logging.getLogger(__name__)

def init_cosmos_db(app):
    """Initialize Cosmos DB client and container"""
    global cosmos_client, database, container
    
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
        
        # Initialize client with managed identity if enabled, otherwise use key
        if use_managed_identity:
            logger.info("Using managed identity for Cosmos DB authentication")
            credential = DefaultAzureCredential()
            cosmos_client = CosmosClient(endpoint, credential)
        elif key:
            logger.info("Using access key for Cosmos DB authentication")
            cosmos_client = CosmosClient(endpoint, key)
        else:
            logger.error("Neither managed identity nor access key configured for Cosmos DB")
            return False
        
        # Create database if not exists
        database = cosmos_client.create_database_if_not_exists(id=database_name)
        
        # Create container if not exists with TTL enabled
        container = database.create_container_if_not_exists(
            id=container_name,
            partition_key=PartitionKey(path="/link_id"),
            default_ttl=86400  # 24 hours TTL in seconds
        )
        
        auth_method = "managed identity" if use_managed_identity else "access key"
        logger.info(f"Cosmos DB initialized using {auth_method}: database={database_name}, container={container_name}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to initialize Cosmos DB: {e}")
        return False
