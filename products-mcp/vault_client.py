import jwt
import hvac
import time
from typing import Dict, Tuple
from requests import Session

import logging

import requests
from config import get_config

# Configure logging level from .env (default to INFO)
LOG_LEVEL = get_config().log_level.upper()
# logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.setLevel(logging.getLevelNamesMapping().get(LOG_LEVEL))

# Initialize a global VaultClient instance
# _vault_client = None


def get_vault_client(x_correlation_id: str):
    # global _vault_client
    # if _vault_client is None:
    config = get_config()
    if not config.vault_addr:
        raise ValueError("VAULT_ADDR not found in configuration")
    _vault_client = VaultClient(config.vault_addr, x_correlation_id)
    return _vault_client


def get_mongodb_credentials(jwt_token: str, x_correlation_id: str) -> Dict:
    """
    Get MongoDB credentials using the global VaultClient instance

    Args:
        jwt_token (str): JWT token in standard format

    Returns:
        Dict: Dictionary containing MongoDB credentials and metadata
    """
    client = get_vault_client(x_correlation_id)
    return client.get_mongodb_credentials(jwt_token)


class VaultClient:
    def __init__(self, vault_addr: str, x_correlation_id: str):
        """
        Initialize VaultClient with Vault server address and multi-user credentials cache

        Args:
            vault_addr (str): Vault server address
        """
        self.vault_addr = vault_addr
        self.x_correlation_id = x_correlation_id
        session = requests.Session()
        session.headers.update({"X-Correlation-Id": x_correlation_id})
        self.client = hvac.Client(url=vault_addr, namespace="admin", session=session)
        # Initialize multi-user credentials cache
        self._credentials_cache = {}

    def _decode_jwt_token(self, jwt_token: str) -> Tuple[str, Dict]:
        """
        Decode JWT token and extract claims

        Args:
            jwt_token (str): JWT token in standard format

        Returns:
            Tuple[str, Dict]: Tuple containing the token and its claims

        Raises:
            ValueError: If the token is invalid or cannot be decoded
        """
        try:
            # Decode JWT without verification
            claims = jwt.decode(jwt_token, options={"verify_signature": False})
            return jwt_token, claims
        except jwt.InvalidTokenError as e:
            raise ValueError(f"Invalid JWT token: {str(e)}")
        except Exception as e:
            raise ValueError(f"Error decoding token: {str(e)}")

    def _is_token_expired(self, token_ttl: float) -> bool:
        """
        Check if token has expired

        Args:
            token_ttl (float): Token time-to-live in seconds

        Returns:
            bool: True if token has expired, False otherwise
        """
        return time.time() >= token_ttl

    def _get_database_role(self, auth_response: Dict) -> str:
        """
        Determine the database role based on the policies in the auth response.
        Checks if the policy contains 'readonly' or 'readwrite' and returns
        the appropriate database role name.

        Args:
            auth_response (Dict): The Vault authentication response containing policies

        Returns:
            str: The database role name to use ('readonly' or 'readwrite')

        Raises:
            Exception: If no matching policy is found
        """
        policies = auth_response["auth"]["policies"]

        # Check policies for readonly or readwrite
        for policy in policies:
            if "readonly" in policy.lower():
                return "readonly"
            if "readwrite" in policy.lower():
                return "readwrite"

        # If no matching policy is found, raise an exception
        raise Exception(
            "No valid database role policy found. Token must have either 'readonly' or 'readwrite' policy."
        )

    def _get_cache_key(self, claims: Dict) -> str:
        """
        Get cache key from JWT claims. The 'sub' claim must be present.

        Args:
            claims (Dict): The JWT claims

        Returns:
            str: The cache key from the 'sub' claim

        Raises:
            ValueError: If 'sub' claim is missing
        """
        cache_key = claims.get("sub")
        if not cache_key:
            raise ValueError("JWT token must contain 'sub' claim")
        return cache_key

    def get_mongodb_credentials(self, jwt_token: str) -> Dict:
        """
        Get MongoDB credentials using Vault authentication.
        First tries to retrieve from cache, if expired or not found,
        generates new credentials. Handles first-time users by creating
        new cache entries.

        Args:
            jwt_token (str): JWT token in standard format

        Returns:
            Dict: Dictionary containing MongoDB credentials and metadata
        """
        # Extract claims from JWT token
        token, claims = self._decode_jwt_token(jwt_token)

        # Get cache key from 'sub' claim
        cache_key = self._get_cache_key(claims)

        # Check cache for existing valid credentials
        cached_data = self._credentials_cache.get(cache_key)
        if cached_data:
            # Check if auth token or credentials have expired
            if not (
                self._is_token_expired(cached_data["auth_token_ttl"])
                or self._is_token_expired(cached_data["credentials_ttl"])
            ):
                return cached_data

        # Authenticate with Vault using JWT
        try:
            auth_response = self.client.auth.jwt.jwt_login(
                role="default",  # Role name should be configured in Vault
                jwt=jwt_token,
                path="azure-jwt",
            )

            # Extract auth token and its TTL
            auth_token = auth_response["auth"]["client_token"]
            auth_token_ttl = time.time() + auth_response["auth"]["lease_duration"]

            # Get the appropriate database role based on auth response policies
            db_role = self._get_database_role(auth_response)

            # Configure client to use the new token
            self.client.token = auth_token

            # Generate MongoDB credentials with the determined role
            db_cred_response = self.client.secrets.database.generate_credentials(
                name=db_role,  # Using the role determined from policies
                mount_point="database",
            )

            # Extract credentials and their TTL
            credentials_data = db_cred_response["data"]
            credentials_ttl = time.time() + db_cred_response["lease_duration"]

            # Prepare cache data with metadata
            cache_data = {
                "auth_token": auth_token,
                "auth_token_ttl": auth_token_ttl,
                "username": credentials_data["username"],
                "password": credentials_data["password"],
                "credentials_ttl": credentials_ttl,
                "created_at": time.time(),
                "last_accessed": time.time(),
                "user_metadata": {
                    "sub": cache_key,
                    "auth_method": "jwt",
                    "database_role": db_role,
                },
            }

            # Update cache with new or refreshed data
            self._credentials_cache[cache_key] = cache_data

            return cache_data

        except Exception as e:
            raise Exception(f"Failed to get MongoDB credentials: {str(e)}")
