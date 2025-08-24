"""
Configuration management for the MCP server.

This module handles environment variables and application settings
for AWS DocumentDB connection and server configuration.
"""

from typing import Optional
from pydantic import Field, field_validator
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


class Config(BaseSettings):
    """
    Configuration settings for the MCP server.

    All settings can be overridden via environment variables.
    """

    # Database configuration
    db_host: str = Field(default="localhost", description="AWS DocumentDB host")
    db_port: int = Field(default=27017, description="AWS DocumentDB port")
    db_name: str = Field(default="products_db", description="Database name")
    db_username: Optional[str] = Field(default=None, description="Database username")
    db_password: Optional[str] = Field(default=None, description="Database password")
    collection_name: str = Field(
        default="products", description="Products collection name"
    )

    # SSL configuration for AWS DocumentDB
    use_ssl: bool = Field(default=True, description="Use SSL connection")
    ssl_ca_cert_path: Optional[str] = Field(
        default=None, description="Path to SSL CA certificate file"
    )

    # MCP Server configuration
    server_host: str = Field(default="localhost", description="MCP server host")
    server_port: int = Field(default=8000, description="MCP server port")
    server_name: str = Field(default="products-mcp", description="MCP server name")
    server_version: str = Field(default="1.0.0", description="MCP server version")

    # Logging configuration
    log_level: str = Field(default="INFO", description="Logging level")
    log_file: Optional[str] = Field(default=None, description="Log file path")

    # Application settings
    debug: bool = Field(default=False, description="Debug mode")
    max_results: int = Field(
        default=100, description="Maximum number of results to return"
    )

    # JWT validation  settings
    jwt_issuer: str = Field(default=None, description="JWT issuer")
    jwt_audience: str = Field(default=None, description="JWT audience")
    jwks_uri: str = Field(default=None, description="JWT signing keys")
    # entra_tenant_id: str = Field(default=None, description="Entra tenant ID")

    # Vault settings
    vault_addr: str = Field(default=None, description="Vault address")

    @field_validator("log_level")
    @classmethod
    def validate_log_level(cls, v):
        """Validate log level is valid."""
        valid_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if v.upper() not in valid_levels:
            raise ValueError(f"Log level must be one of {valid_levels}")
        return v.upper()

    @field_validator("db_port", "server_port")
    @classmethod
    def validate_port(cls, v):
        """Validate port is in valid range."""
        if not 1 <= v <= 65535:
            raise ValueError("Port must be between 1 and 65535")
        return v

    @field_validator("max_results")
    @classmethod
    def validate_max_results(cls, v):
        """Validate max results is positive."""
        if v <= 0:
            raise ValueError("Max results must be positive")
        return v

    def get_server_info(self) -> dict:
        """
        Get server information dictionary.

        Returns:
            dict: Server information
        """
        return {
            "name": self.server_name,
            "version": self.server_version,
            "host": self.server_host,
            "port": self.server_port,
            "debug": self.debug,
        }

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
    }


# Global configuration instance
_config: Optional[Config] = None


def get_config() -> Config:
    """
    Get global configuration instance.

    Returns:
        Config: Global configuration instance
    """
    global _config
    if _config is None:
        _config = Config()
    return _config
