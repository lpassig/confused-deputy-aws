# ProductsAgent FastAPI

A FastAPI application that exposes the ProductsAgent with JWT authentication and Microsoft Entra ID token exchange.

## Features

- **JWT Authentication**: Validates JWT tokens from Microsoft Entra ID
- **Token Exchange**: Implements OAuth 2.0 on-behalf-of flow with Microsoft Entra ID
- **ProductsAgent Integration**: Securely invokes the ProductsAgent with exchanged tokens
- **Security**: Comprehensive security features including JWKS validation and secure token handling
- **Error Handling**: Robust error handling with detailed error responses
- **Monitoring**: Health check endpoints and comprehensive logging

## Architecture

1. **Authentication Flow**:
   - Client sends request with JWT Bearer token in Authorization header
   - API validates JWT token using Microsoft Entra ID JWKS endpoint
   - API exchanges user token for on-behalf-of token using Microsoft Entra ID OAuth endpoint
   
2. **Agent Invocation**:
   - API invokes ProductsAgent with the on-behalf-of token
   - ProductsAgent uses the token to authenticate with downstream MCP services
   - Response is returned to the client

## Prerequisites

- Python 3.11.4+
- uv package manager
- Microsoft Entra ID application registration
- MCP server running on localhost:8000

## Environment Configuration

Update the `.env` file with your Microsoft Entra ID configuration:

```bash
# JWT Validation
JWKS_URI=https://login.windows.net/common/discovery/keys
JWT_ISSUER=https://login.microsoftonline.com/{tenant_id}/v2.0
JWT_AUDIENCE={your_application_id}
ENTRA_TENANT_ID={tenant_id}

# Microsoft Entra ID OAuth On-Behalf-Of Flow
ENTRA_CLIENT_ID={your_client_id}
ENTRA_CLIENT_SECRET={your_client_secret}
ENTRA_SCOPE=https://graph.microsoft.com/.default
ENTRA_TOKEN_URL=https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token
```

## Installation

Install dependencies using uv:

```bash
uv sync
```

## Running the Application

### Development

```bash
# Using uv
uv run python main.py

# Or using uvicorn directly
uv run uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

### Production

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8001 --workers 4
```

### Docker (Recommended for Production)

#### Quick Start

```bash
# Build production image for current platform
./docker-build.sh

# Run the container
docker run -d \
  --name products-agent \
  -p 8001:8001 \
  --env-file .env \
  products-agent:latest
```

#### Multi-Architecture Builds

The build script supports building for multiple architectures:

```bash
# Build for both ARM64 and AMD64
./docker-build.sh --multi-arch

# Build for specific architecture
./docker-build.sh --arm64    # ARM64 only
./docker-build.sh --amd64    # AMD64 only
```

#### Development with Docker

```bash
# Build development image with debugging tools
./docker-build.sh --dev

# Run with hot reload (mount source code)
docker run -d \
  --name products-agent-dev \
  -p 8001:8001 \
  --env-file .env \
  -v $(pwd):/app \
  products-agent:latest
```

#### Registry Deployment

```bash
# Build and push to registry
./docker-build.sh --multi-arch --push --registry myregistry.com/myproject

# With custom tag
./docker-build.sh --tag v1.0.0 --push --registry myregistry.com/myproject
```

#### Build Script Options

```bash
./docker-build.sh --help  # Show all options

# Common options:
--dev                     # Build development image
--prod                    # Build production image (default)
--multi-arch             # Build for arm64 and amd64
--tag TAG               # Custom image tag
--registry URL          # Registry to push to
--push                  # Push to registry after build
--dry-run              # Show commands without executing
```

## API Endpoints

### Health Check
- **GET** `/health` - Returns application health status

### Authentication Required Endpoints

All endpoints below require a valid JWT Bearer token in the Authorization header.

### Agent Invocation
- **POST** `/agent/invoke` - Invoke the ProductsAgent
  - Request body: `{"prompt": "your prompt here"}`
  - Response: `{"response": "agent response", "success": true}`

### User Information
- **GET** `/user/info` - Get current user information from JWT token

## Authentication

Include the JWT token in the Authorization header:

```bash
curl -X POST "http://localhost:8001/agent/invoke" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"prompt": "List all products"}'
```

## Error Handling

The API returns structured error responses:

```json
{
  "detail": "Error description",
  "success": false,
  "error_code": "ERROR_TYPE"
}
```

Common error codes:
- `AUTH_ERROR` - Authentication failed
- `TOKEN_EXCHANGE_ERROR` - Token exchange with Entra ID failed
- `AGENT_ERROR` - ProductsAgent invocation failed
- `VALIDATION_ERROR` - Request validation failed
- `INTERNAL_ERROR` - Internal server error

## Security Considerations

- JWT tokens are validated using Microsoft Entra ID JWKS endpoint
- Original user tokens are never logged or stored
- On-behalf-of tokens are securely passed to the ProductsAgent
- CORS is configured (update for production)
- Comprehensive input validation using Pydantic models

## Monitoring and Logging

The application logs:
- Authentication events
- Token exchange operations
- Agent invocations
- Error conditions
- Performance metrics

Log format: `%(asctime)s - %(name)s - %(levelname)s - %(message)s`

## Development

### Project Structure

```
products-agent/
├── auth/                   # Authentication modules
│   ├── __init__.py
│   ├── jwt_utils.py       # JWT validation utilities
│   └── entra_token_service.py  # Token exchange service
├── api_models.py          # Pydantic models for API
├── exceptions.py          # Custom exception classes
├── main.py               # FastAPI application
├── models.py             # Bedrock model configuration
├── products_agent.py     # ProductsAgent implementation
├── pyproject.toml        # Dependencies
├── .env                  # Environment configuration
└── README.md            # This file
```

### Adding New Features

1. Update API models in `api_models.py`
2. Add new endpoints to `main.py`
3. Update authentication/authorization logic in `auth/`
4. Add appropriate error handling
5. Update documentation

## API Documentation

Interactive API documentation is available at:
- Swagger UI: `http://localhost:8001/docs`
- ReDoc: `http://localhost:8001/redoc`

## Testing Results

The API has been successfully tested with the following results:

✅ **Health Check** - Server starts and responds correctly  
✅ **Authentication Protection** - Properly rejects requests without Authorization header  
✅ **Invalid Token Protection** - Properly handles malformed JWT tokens  
✅ **JWT Token Validation** - Successfully validates tokens and extracts user information  
✅ **Token Exchange Flow** - Successfully exchanges user tokens with Microsoft Entra ID  
✅ **MCP Integration** - Successfully connects to MCP server and invokes ProductsAgent  

## Troubleshooting

### Common Issues

1. **Server Won't Start**
   - Check that all environment variables are set in `.env`
   - Ensure the port 8001 is not already in use
   - Run `uv sync` to install all dependencies

2. **Token Validation Fails**
   - Verify JWKS_URI is correct
   - Check JWT_ISSUER matches your Entra ID tenant
   - Ensure JWT_AUDIENCE matches your application registration
   - Update JWT_AUDIENCE in `.env` to match your token's `aud` claim

3. **Token Exchange Fails**
   - Verify ENTRA_CLIENT_ID and ENTRA_CLIENT_SECRET are correct
   - Check ENTRA_TOKEN_URL is correct for your tenant
   - Ensure the application has proper permissions for on-behalf-of flow
   - Verify ENTRA_SCOPE matches the required API scope

4. **Agent Invocation Fails**
   - Verify MCP server is running on localhost:8000
   - Check that the on-behalf-of token has required permissions
   - Ensure AWS credentials are configured for Bedrock access

### Environment Configuration Issues

If you see "Missing required Entra ID configuration" errors, ensure your `.env` file contains:

```bash
# JWT Validation
JWKS_URI=https://login.windows.net/common/discovery/keys
JWT_ISSUER=https://login.microsoftonline.com/{your-tenant-id}/v2.0
JWT_AUDIENCE={your-application-id}
ENTRA_TENANT_ID={your-tenant-id}

# Microsoft Entra ID OAuth On-Behalf-Of Flow
ENTRA_CLIENT_ID={your-client-id}
ENTRA_CLIENT_SECRET={your-client-secret}
ENTRA_SCOPE={your-api-scope}
ENTRA_TOKEN_URL=https://login.microsoftonline.com/{your-tenant-id}/oauth2/v2.0/token
```

### Testing the API

Run the test suite:
```bash
uv run python test_api.py
```

Or test individual endpoints:
```bash
# Health check
curl http://localhost:8001/health

# User info (requires valid JWT token)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" http://localhost:8001/user/info

# Agent invocation (requires valid JWT token)
curl -X POST "http://localhost:8001/agent/invoke" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"prompt": "List all products"}'
```

### Logs

The application provides detailed logging for troubleshooting:
```bash
# Start server to see logs in real-time
uv run uvicorn main:app --host 0.0.0.0 --port 8001 --log-level info
```

Logs include:
- Authentication events and token validation
- Token exchange operations with Microsoft Entra ID
- ProductsAgent invocations and MCP communications
- Error details with stack traces
- Performance metrics
