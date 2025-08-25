"""
Database utilities for AWS DocumentDB connection management.

This module provides a MongoDB connection manager with connection pooling,
error handling, and AWS DocumentDB specific configurations.
"""

import logging
import time
from typing import Dict, Optional, Tuple

from pymongo import MongoClient

from config import Config, get_config
from jwt_verifier import decode_jwt_token
from vault_client import get_mongodb_credentials

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DatabaseManager:
    """
    MongoDB/AWS DocumentDB connection manager.

    Provides connection management, connection pooling, and database operations
    for AWS DocumentDB with proper SSL configuration and error handling.
    """

    def __init__(self, config: Optional[Config] = None):
        """
        Initialize the database manager.

        Args:
            config: Configuration object with database settings
        """
        self.config = config or Config()
        self._connections: Dict[str, Tuple[MongoClient, float, float]] = {}

    def get_mongo_client(self, jwt_token: str) -> MongoClient:
        """
        Establish connection to AWS DocumentDB.

        Returns:
            MongoClient: Connected MongoDB client

        Raises:
            ConnectionFailure: If connection cannot be established
            ConfigurationError: If configuration is invalid
        """
        try:
            # Decode JWT to get subject claim
            token_data = decode_jwt_token(jwt_token)
            sub = token_data.get("sub")
            if not sub:
                raise ValueError("JWT token does not contain 'sub' claim")

            # Check if we have a cached connection
            if sub in self._connections:
                client, creation_time, duration = self._connections[sub]
                # Check if connection has expired
                if time.time() - creation_time < duration:
                    logger.info(f"Using cached connection for {sub}")

                    # Check if the client is still connected
                    try:
                        # The 'ping' command is a lightweight way to check connection health
                        client.admin.command("ping")
                        logger.info(f"Cached connection for {sub} is active")
                    except Exception:
                        logger.info(
                            f"Cached connection for {sub} is no longer active, reconnecting..."
                        )
                        self.close_connection(sub)
                    else:
                        return client
                    return client
                else:
                    # Connection expired, clean up
                    self.close_connection(sub)

            # Get fresh credentials from Vault
            credentials = get_mongodb_credentials(jwt_token)
            config = get_config()

            connection_string = (
                f"mongodb://{credentials['username']}:{credentials['password']}"
                f"@{config.db_host}:{config.db_port}"
                f"/{config.db_name}?retryWrites=false"
            )

            client_options = {
                "maxIdleTimeMS": 30000,  # 30 seconds
                "waitQueueTimeoutMS": 10000,  # 10 seconds
                "directConnection": True,
            }

            # # Configure SSL for AWS DocumentDB if enabled
            # if self.config.use_ssl:
            #     client_options["tls"] = True
            #     client_options["tlsCAFile"] = self.config.ssl_ca_cert_path

            client = MongoClient(connection_string, **client_options)
            # Cache the connection with its creation time and TTL
            self._connections[sub] = (
                client,
                time.time(),
                credentials["credentials_ttl"],
            )
            return client

        except Exception as e:
            raise RuntimeError(f"Failed to get MongoDB connection: {str(e)}")

    def close_connection(self, sub: str) -> None:
        """Close and remove a specific connection"""
        if sub in self._connections:
            client, _, _ = self._connections[sub]
            client.close()
            del self._connections[sub]

    def close_all_connections(self) -> None:
        """Close all connections"""
        for sub in list(self._connections.keys()):
            self.close_connection(sub)


# Global database manager instance
_db_manager: Optional[DatabaseManager] = None


def get_db_manager() -> DatabaseManager:
    """
    Get global database manager instance.

    Returns:
        DatabaseManager: Global database manager instance
    """
    global _db_manager
    if _db_manager is None:
        _db_manager = DatabaseManager()
    return _db_manager
