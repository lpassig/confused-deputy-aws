"""Custom exceptions for the ProductsAgent API."""

from typing import Optional


class BaseAPIException(Exception):
    """Base exception for API errors."""
    
    def __init__(self, message: str, error_code: str = None):
        self.message = message
        self.error_code = error_code or "UNKNOWN_ERROR"
        super().__init__(self.message)


class AuthenticationError(BaseAPIException):
    """Exception raised for authentication failures."""
    
    def __init__(self, message: str = "Authentication failed"):
        super().__init__(message, "AUTH_ERROR")


class AuthorizationError(BaseAPIException):
    """Exception raised for authorization failures."""
    
    def __init__(self, message: str = "Authorization failed"):
        super().__init__(message, "AUTHZ_ERROR")


class TokenExchangeError(BaseAPIException):
    """Exception raised for token exchange failures."""
    
    def __init__(self, message: str = "Token exchange failed"):
        super().__init__(message, "TOKEN_EXCHANGE_ERROR")


class AgentError(BaseAPIException):
    """Exception raised for ProductsAgent failures."""
    
    def __init__(self, message: str = "Agent invocation failed"):
        super().__init__(message, "AGENT_ERROR")


class ValidationError(BaseAPIException):
    """Exception raised for validation failures."""
    
    def __init__(self, message: str = "Validation failed"):
        super().__init__(message, "VALIDATION_ERROR")


class ExternalServiceError(BaseAPIException):
    """Exception raised for external service failures."""
    
    def __init__(self, message: str = "External service error"):
        super().__init__(message, "EXTERNAL_SERVICE_ERROR")
