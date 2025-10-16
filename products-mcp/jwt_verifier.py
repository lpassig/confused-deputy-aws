import logging
import os
import time
from typing import Dict, List, Optional, Union
import jwt
import httpx
from jwt import PyJWKClient
from datetime import datetime, timezone, timedelta

from fastmcp.server.auth.providers.jwt import JWTVerifier
from config import get_config

# Configure logging
# Configure logging level from .env (default to INFO)
LOG_LEVEL = get_config().log_level.upper()
# logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.setLevel(logging.getLevelNamesMapping().get(LOG_LEVEL))


def get_jwt_verifier() -> JWTVerifier:
    """Create JWT verifier with debug logging to identify OBO token rejection issues.

    Returns:
        JWTVerifier: Configured JWT verifier instance
    """
    logger.info("Creating debug JWT verifier for OBO flow testing")

    # Create a debug JWT verifier that logs before calling parent verification
    class DebugJWTVerifier(JWTVerifier):
        def __init__(self, *args, **kwargs):
            logger.info("DebugJWTVerifier __init__ called")
            # Initialize parent class properly to ensure FastMCP routes work
            super().__init__(
                jwks_uri=os.getenv("JWKS_URI"),
                issuer=os.getenv("JWT_ISSUER"),
                audience=os.getenv("JWT_AUDIENCE"),
                algorithm="RS256"
            )
            logger.info(f"DebugJWTVerifier initialized with:")
            logger.info(f"  JWKS_URI: {self.jwks_uri}")
            logger.info(f"  Issuer: {self.issuer}")
            logger.info(f"  Audience: {self.audience}")
        
        def verify_token(self, token: str) -> Dict:
            """Override to add detailed logging before calling parent verification."""
            try:
                logger.info(f"DebugJWTVerifier.verify_token called with token: {token[:50]}...")
                
                # Decode without verification to see the payload
                unverified = jwt.decode(token, options={"verify_signature": False})
                logger.info(f"Token claims:")
                logger.info(f"  aud: {unverified.get('aud')}")
                logger.info(f"  iss: {unverified.get('iss')}")
                logger.info(f"  scp: {unverified.get('scp')}")
                logger.info(f"  roles: {unverified.get('roles')}")
                logger.info(f"  ver: {unverified.get('ver')}")
                logger.info(f"Expected values:")
                logger.info(f"  aud: {self.audience}")
                logger.info(f"  iss: {self.issuer}")
                
                # Call parent to see exact error
                logger.info("Calling parent verify_token...")
                result = super().verify_token(token)
                logger.info("✅ Token verification successful!")
                return result
                
            except Exception as e:
                logger.error(f"❌ JWT verification failed: {type(e).__name__}: {e}")
                raise
        
        # Let parent handle get_routes() and get_middleware()

    return DebugJWTVerifier()


async def get_jwt_token_from_header(headers: dict) -> str:
    # Get authorization header
    auth_header = headers.get("authorization", "")
    is_bearer = auth_header.startswith("Bearer ")
    jwt_token = auth_header.split(" ")[1] if is_bearer else ""
    return jwt_token


def decode_jwt_token(token: str) -> Dict:
    """
    Decode JWT token without verification to extract claims.
    This is used for getting basic token information like subject claim
    without full validation.

    Args:
        token (str): JWT token string

    Returns:
        Dict: Decoded token claims

    Raises:
        ValueError: If token is invalid or cannot be decoded
    """
    try:
        # Decode without verification for internal use
        claims = jwt.decode(token, options={"verify_signature": False})
        return claims
    except jwt.InvalidTokenError as e:
        raise ValueError(f"Invalid JWT token: {str(e)}")
    except Exception as e:
        raise ValueError(f"Error decoding token: {str(e)}")
