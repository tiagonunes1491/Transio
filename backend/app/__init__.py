from azure.cosmos import CosmosClient, PartitionKey
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
        database_name = app.config.get('COSMOS_DATABASE_NAME', 'SecureSharer')
        container_name = app.config.get('COSMOS_CONTAINER_NAME', 'secrets')
        
        if not endpoint or not key:
            logger.error("Cosmos DB endpoint or key not configured")
            return False
            
        # Initialize client
        cosmos_client = CosmosClient(endpoint, key)
        
        # Create database if not exists
        database = cosmos_client.create_database_if_not_exists(id=database_name)
        
        # Create container if not exists with TTL enabled
        container = database.create_container_if_not_exists(
            id=container_name,
            partition_key=PartitionKey(path="/link_id"),
            default_ttl=86400  # 24 hours TTL in seconds
        )
        
        logger.info(f"Cosmos DB initialized: database={database_name}, container={container_name}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to initialize Cosmos DB: {e}")
        return False
