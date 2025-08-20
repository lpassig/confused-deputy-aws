from pydantic import BaseModel, Field
from typing import Optional, Dict, Any


class AgentRequest(BaseModel):
    """Request model for agent invocation."""
    prompt: str = Field(..., description="The user prompt to send to the ProductsAgent", min_length=1)
    
    class Config:
        json_schema_extra = {
            "example": {
                "prompt": "Could you please list all products?"
            }
        }


class AgentResponse(BaseModel):
    """Response model for agent invocation."""
    response: str = Field(..., description="The response from the ProductsAgent")
    success: bool = Field(True, description="Indicates if the request was successful")
    
    class Config:
        json_schema_extra = {
            "example": {
                "response": "Here are all the products in the catalog:\n\n1. Product A - $99.99\n2. Product B - $149.99",
                "success": True
            }
        }


class ErrorResponse(BaseModel):
    """Error response model."""
    detail: str = Field(..., description="Error message")
    success: bool = Field(False, description="Indicates the request failed")
    error_code: Optional[str] = Field(None, description="Error code for client handling")
    
    class Config:
        json_schema_extra = {
            "example": {
                "detail": "Authentication failed",
                "success": False,
                "error_code": "AUTH_ERROR"
            }
        }


class HealthResponse(BaseModel):
    """Health check response model."""
    status: str = Field(..., description="Service status")
    timestamp: str = Field(..., description="Current timestamp")
    version: str = Field(..., description="Application version")
    
    class Config:
        json_schema_extra = {
            "example": {
                "status": "healthy",
                "timestamp": "2024-01-15T10:30:00Z",
                "version": "0.1.0"
            }
        }
