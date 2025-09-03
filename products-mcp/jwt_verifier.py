import logging
import os
from typing import Dict
import jwt

from fastmcp.server.auth.providers.jwt import JWTVerifier
from config import get_config

# Configure logging
# Configure logging level from .env (default to INFO)
LOG_LEVEL = get_config().log_level.upper()
# logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.setLevel(logging.getLevelNamesMapping().get(LOG_LEVEL))


def get_jwt_verifier() -> JWTVerifier:
    """Create JWT verifier from environment variables.

    Returns:
        JWTVerifier: Configured JWT verifier instance
    """
    jwks_uri = os.getenv("JWKS_URI")
    jwt_issuer = os.getenv("JWT_ISSUER")
    jwt_audience = os.getenv("JWT_AUDIENCE")

    if not all([jwks_uri, jwt_issuer, jwt_audience]):
        raise ValueError(
            "Missing required JWT configuration: JWKS_URI, JWT_ISSUER, JWT_AUDIENCE must be set in environment"
        )

    logger.info(f"Configuring JWT verifier with issuer: {jwt_issuer}")
    logger.info(f"JWT audience: {jwt_audience}")
    logger.info(f"JWKS URI: {jwks_uri}")

    return JWTVerifier(
        jwks_uri=jwks_uri,
        issuer=jwt_issuer,
        audience=jwt_audience,
        algorithm="RS256",  # Standard for Azure AD / Microsoft Entra ID
    )


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
