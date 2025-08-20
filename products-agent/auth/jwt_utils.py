import os
import jwt
import httpx
from typing import Dict, Any, Optional
from fastapi import HTTPException, status
from jwt import PyJWKClient
from datetime import datetime, timezone


class JWTValidator:
    def __init__(self):
        self.jwks_uri = os.getenv("JWKS_URI")
        self.jwt_issuer = os.getenv("JWT_ISSUER")
        self.jwt_audience = os.getenv("JWT_AUDIENCE")
        
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
            # Get the signing key from JWKS
            signing_key = self.jwks_client.get_signing_key_from_jwt(token)
            
            # Decode and validate the token
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256"],
                audience=self.jwt_audience,
                issuer=self.jwt_issuer,
                options={"verify_exp": True}
            )
            
            # Additional validation
            self._validate_payload(payload)
            
            return payload
            
        except jwt.ExpiredSignatureError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired"
            )
        except jwt.InvalidTokenError as e:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid token: {str(e)}"
            )
        except Exception as e:
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
