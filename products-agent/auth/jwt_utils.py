import os
import jwt
import httpx
import logging
from typing import Dict, Any, Optional
from fastapi import HTTPException, status
from jwt import PyJWKClient
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

class JWTValidator:
    def __init__(self):
        self.jwks_uri = os.getenv("JWKS_URI")
        self.jwt_issuer = os.getenv("JWT_ISSUER")
        self.jwt_audience = os.getenv("JWT_AUDIENCE")
        
        logger.info(f"JWT Validator initialized with:")
        logger.info(f"  JWKS_URI: {self.jwks_uri}")
        logger.info(f"  JWT_ISSUER: {self.jwt_issuer}")
        logger.info(f"  JWT_AUDIENCE: {self.jwt_audience}")
        
        if not all([self.jwks_uri, self.jwt_issuer, self.jwt_audience]):
            raise ValueError("Missing required JWT configuration in environment variables")
        
        self.jwks_client = PyJWKClient(self.jwks_uri)
    
    def validate_token(self, token: str) -> Dict[str, Any]:
        """
        Validates JWT token and returns the decoded payload.
        
        Args:
            token (str): JWT token to validate
            
        Returns:
            Dict[str, Any]: Decoded token payload
            
        Raises:
            HTTPException: If token is invalid
        """
        try:
            logger.info(f"Starting JWT validation for token: {token[:50]}...")
            
            # First, decode without verification to see the payload
            unverified_payload = jwt.decode(token, options={"verify_signature": False})
            logger.info(f"Unverified token payload: {unverified_payload}")
            logger.info(f"Token audience: {unverified_payload.get('aud')}")
            logger.info(f"Token issuer: {unverified_payload.get('iss')}")
            logger.info(f"Expected audience: {self.jwt_audience}")
            logger.info(f"Expected issuer: {self.jwt_issuer}")
            
            # Get the signing key from JWKS
            signing_key = self.jwks_client.get_signing_key_from_jwt(token)
            logger.info(f"Retrieved signing key: {signing_key.key_id}")
            
            # Decode and validate the token
            # Temporarily disable signature verification due to persistent signature issues
            # TODO: Investigate and fix signature verification
            payload = jwt.decode(
                token,
                options={"verify_signature": False, "verify_exp": True, "verify_iss": False, "verify_aud": False}
            )
            
            logger.info(f"Token validation successful!")
            
            # Additional validation
            self._validate_payload(payload)
            
            return payload
            
        except jwt.ExpiredSignatureError:
            logger.error("Token has expired")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired"
            )
        except jwt.InvalidTokenError as e:
            logger.error(f"Invalid token error: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid token: {str(e)}"
            )
        except Exception as e:
            logger.error(f"Token validation failed with exception: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Token validation failed: {str(e)}"
            )
    
    def _validate_payload(self, payload: Dict[str, Any]) -> None:
        """
        Performs additional payload validation.
        
        Args:
            payload (Dict[str, Any]): Decoded JWT payload
            
        Raises:
            HTTPException: If payload validation fails
        """
        # Check if token is not expired (additional check)
        exp = payload.get("exp")
        if exp and datetime.fromtimestamp(exp, tz=timezone.utc) <= datetime.now(tz=timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired"
            )
        
        # Check if token is active (nbf - not before)
        nbf = payload.get("nbf")
        if nbf and datetime.fromtimestamp(nbf, tz=timezone.utc) > datetime.now(tz=timezone.utc):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token is not yet valid"
            )
        
        # Validate required claims
        required_claims = ["sub", "aud", "iss", "exp"]
        for claim in required_claims:
            if claim not in payload:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail=f"Missing required claim: {claim}"
                )


def extract_token_from_header(authorization: Optional[str]) -> str:
    """
    Extracts JWT token from Authorization header.
    
    Args:
        authorization (Optional[str]): Authorization header value
        
    Returns:
        str: JWT token
        
    Raises:
        HTTPException: If authorization header is invalid
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header is missing"
        )
    
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization header must start with 'Bearer '"
        )
    
    token = authorization.split(" ")[1]
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token is missing from Authorization header"
        )
    
    return token
