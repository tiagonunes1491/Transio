#!/usr/bin/env python3
"""
Script to set up the Cosmos DB emulator with the required database and container.
This should be run once after the emulator starts to create the necessary infrastructure.
"""

import os
import sys
import time
from azure.cosmos import CosmosClient, PartitionKey
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__name__)

def setup_cosmos_emulator():
    """Set up the Cosmos DB emulator with database and container"""
    
    # Cosmos DB emulator configuration
    endpoint = "https://localhost:8081"
    key = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=="
    database_name = "Transio"
    container_name = "secrets"
    
    try:
        # Connect to emulator (disable SSL verification for self-signed cert)
        client = CosmosClient(endpoint, key, connection_verify=False)
        logger.info("Connected to Cosmos DB emulator")
        
        # Create database
        database = client.create_database_if_not_exists(id=database_name)
        logger.info(f"Database '{database_name}' ready")
        
        # Create container with 24-hour TTL
        container = database.create_container_if_not_exists(
            id=container_name,
            partition_key=PartitionKey(path="/link_id"),
            default_ttl=86400  # 24 hours in seconds
        )
        logger.info(f"Container '{container_name}' ready with 24-hour TTL")
        
        # Verify container properties
        properties = container.read()
        logger.info(f"Container TTL setting: {properties.get('defaultTtl', 'Not set')}")
        
        logger.info("✅ Cosmos DB emulator setup completed successfully!")
        return True
        
    except Exception as e:
        logger.error(f"❌ Failed to set up Cosmos DB emulator: {e}")
        return False

def wait_for_emulator(max_attempts=30, delay=5):
    """Wait for the Cosmos DB emulator to be ready"""
    endpoint = "https://localhost:8081"
    key = "C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw=="
    
    for attempt in range(max_attempts):
        try:
            client = CosmosClient(endpoint, key, connection_verify=False)
            # Try a simple operation to test connectivity
            list(client.list_databases())
            logger.info("Cosmos DB emulator is ready!")
            return True
        except Exception as e:
            if attempt < max_attempts - 1:
                logger.info(f"Waiting for emulator... (attempt {attempt + 1}/{max_attempts})")
                time.sleep(delay)
            else:
                logger.error(f"Emulator not ready after {max_attempts} attempts: {e}")
                return False
    
    return False

if __name__ == "__main__":
    logger.info("🚀 Setting up Cosmos DB emulator for Transio...")
    
    # Wait for emulator to be ready
    if not wait_for_emulator():
        sys.exit(1)
    
    # Set up database and container
    if setup_cosmos_emulator():
        sys.exit(0)
    else:
        sys.exit(1)
