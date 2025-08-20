import os
import logging
from datetime import datetime
from typing import Dict, Any, Optional

from fastapi import FastAPI, Depends, Header, HTTPException, status
from fastapi.security import HTTPBearer
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from dotenv import load_dotenv

from auth.jwt_utils import JWTValidator, extract_token_from_header
from auth.entra_token_service import get_entra_token_service
from api_models import AgentRequest, AgentResponse, ErrorResponse, HealthResponse
from products_agent import ProductsAgent

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Global instances
jwt_validator = None
products_agent = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan manager for FastAPI application."""
    global jwt_validator, products_agent

    logger.info("Starting ProductsAgent FastAPI application")

    try:
        # Initialize global components
        jwt_validator = JWTValidator()
        products_agent = ProductsAgent()

        logger.info("Application initialized successfully")
        yield

    except Exception as e:
        logger.error(f"Failed to initialize application: {e}")
        raise
    finally:
        logger.info("Application shutdown complete")


# Initialize FastAPI app with lifespan manager
app = FastAPI(
    title="ProductsAgent API",
    description="FastAPI application for ProductsAgent with JWT authentication and Microsoft Entra ID token exchange",
    version="0.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security scheme
security = HTTPBearer()


async def get_current_user(
    authorization: Optional[str] = Header(None),
) -> Dict[str, Any]:
    """
    Dependency to validate JWT token and return user information.

    Args:
        authorization: Authorization header with Bearer token

    Returns:
        Dict containing validated JWT payload

    Raises:
        HTTPException: If authentication fails
    """
    try:
        # Extract token from header
        token = extract_token_from_header(authorization)

        # Validate token
        payload = jwt_validator.validate_token(token)

        # Add the original token to payload for later use
        payload["_original_token"] = token

        logger.info(
            f"Successfully authenticated user: {payload.get('preferred_username', 'unknown')}"
        )
        return payload

    except HTTPException:
        # Re-raise HTTP exceptions from auth utilities
        raise
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication failed"
        )


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    return HealthResponse(
        status="healthy", timestamp=datetime.utcnow().isoformat() + "Z", version="0.1.0"
    )


@app.post(
    "/agent/invoke",
    response_model=AgentResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Authentication failed"},
        403: {"model": ErrorResponse, "description": "Token exchange failed"},
        500: {"model": ErrorResponse, "description": "Internal server error"},
    },
)
async def invoke_agent(
    request: AgentRequest, current_user: Dict[str, Any] = Depends(get_current_user)
):
    """
    Invoke the ProductsAgent with user prompt.

    This endpoint:
    1. Validates the JWT token in the Authorization header
    2. Exchanges the user token for an on-behalf-of token using Microsoft Entra ID
    3. Invokes the ProductsAgent with the on-behalf-of token
    4. Returns the agent's response
    """
    try:
        logger.info(
            f"Processing agent request for user: {current_user.get('preferred_username', 'unknown')}"
        )

        # Get the original user token
        user_token = current_user["_original_token"]

        # Exchange user token for on-behalf-of token
        logger.info("Exchanging user token for on-behalf-of token")
        entra_service = get_entra_token_service()
        obo_token = await entra_service.exchange_token_on_behalf_of(user_token)

        # Invoke the ProductsAgent with the on-behalf-of token
        logger.info("Invoking ProductsAgent")
        agent_response = await products_agent.invoke(
            request.prompt, jwt_token=obo_token
        )

        return AgentResponse(response=agent_response, success=True)

    except HTTPException:
        # Re-raise HTTP exceptions (from token exchange, etc.)
        raise
    except Exception as e:
        logger.error(f"Error processing agent request: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process agent request: {str(e)}",
        )


@app.get("/user/info")
async def get_user_info(current_user: Dict[str, Any] = Depends(get_current_user)):
    """
    Get current user information from JWT token.
    """
    # Remove the original token from response for security
    user_info = current_user.copy()
    user_info.pop("_original_token", None)

    return {
        "user_id": user_info.get("sub"),
        "name": user_info.get("name"),
        "email": user_info.get("preferred_username"),
        "tenant_id": user_info.get("tid"),
        "groups": user_info.get("groups", []),
        "scopes": user_info.get("scp", "").split() if user_info.get("scp") else [],
    }


# Exception handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc: HTTPException):
    """Custom HTTP exception handler."""
    from fastapi.responses import JSONResponse

    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail, "success": False, "error_code": "HTTP_ERROR"},
    )


@app.exception_handler(Exception)
async def general_exception_handler(request, exc: Exception):
    """General exception handler for unhandled exceptions."""
    logger.error(f"Unhandled exception: {exc}")
    from fastapi.responses import JSONResponse

    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "success": False,
            "error_code": "INTERNAL_ERROR",
        },
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True, log_level="info")
