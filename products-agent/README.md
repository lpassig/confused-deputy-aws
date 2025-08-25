# ProductsAgent API

A secure application that provides an intelligent product management interface powered by AWS Bedrock and integrated with Microsoft Entra ID authentication. This service acts as a bridge between authenticated clients and AI agents, implementing secure token propagation and OAuth 2.0 on-behalf-of flows.

- 🤖 **AI-Powered Product Management**: Intelligent product queries and operations using AWS Bedrock
- 🔐 **JWT Authentication**: Validates JWT tokens from Microsoft Entra ID
- 🔄 **Token Exchange**: Implements OAuth 2.0 on-behalf-of flow with Microsoft Entra ID
- 🏗️ **MCP Integration**: Connects to Model Context Protocol (MCP) servers for data access
- 🛡️ **Security**: Comprehensive security features including JWKS validation


## Architecture

### Authentication Flow
1. Client sends request with JWT Bearer token in Authorization header
2. API validates JWT token using Microsoft Entra ID JWKS endpoint
3. API exchanges user token for on-behalf-of token using Microsoft Entra ID OAuth endpoint

### Agent Processing Flow
1. API receives user prompt and processes it through the ProductsAgent
2. ProductsAgent uses AWS Bedrock models for intelligent responses
3. Agent connects to MCP server for product database operations
4. Structured response is returned to the client

### Product Operations
The ProductsAgent supports natural language queries for:
- **List Products**: "Show me all products" or "List all products"
- **Search Products**: "Find laptops" or "Search for products containing 'phone'"
- **Create Products**: "Create a new laptop priced at $999"
- **Update Products**: "Update product XYZ to cost $150"
- **Delete Products**: "Delete product ABC"
- **Sort Products**: "Show me products sorted by price"

## Prerequisites

- Python 3.11.4+ (Python 3.12 recommended)
- [uv](https://github.com/astral-sh/uv) package manager (recommended)
- Docker and Docker Compose (for containerized deployment)
- AWS account with Bedrock access
- Microsoft Entra ID tenant with configured application registration
- MCP server running (products-mcp component)

## Local Development Setup

### 1. Install Dependencies

Using **uv** (recommended):
```bash
# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh

# Navigate to the products-agent directory
cd products-agent

# Create virtual environment
uv venv

# Activate virtual environment
source .venv/bin/activate  # On Unix/macOS
# or .venv\Scripts\activate on Windows

# Install dependencies
uv sync
```

### 2. Environment Configuration

Create a `.env` file with your configuration:

```env
# JWT Validation Configuration
JWKS_URI=https://login.windows.net/common/discovery/keys
JWT_ISSUER=https://login.microsoftonline.com/{your-tenant-id}/v2.0
JWT_AUDIENCE={your-application-id}
ENTRA_TENANT_ID={your-tenant-id}

# Microsoft Entra ID OAuth On-Behalf-Of Flow
ENTRA_CLIENT_ID={your-client-id}
ENTRA_CLIENT_SECRET={your-client-secret}
ENTRA_SCOPE=https://graph.microsoft.com/.default
ENTRA_TOKEN_URL=https://login.microsoftonline.com/{your-tenant-id}/oauth2/v2.0/token

# Bedrock LLM configuration
BEDROCK_MODEL_ID=amazon.nova-pro-v1:0
BEDROCK_REGION=ap-southeast-1

# MCP Server Configuration
PRODUCTS_MCP_SERVER_URL=http://localhost:8080
```

### 3. Run the Application Locally

**Development mode (with hot reload):**
```bash
# Ensure virtual environment is activated
source .venv/bin/activate

# Run with hot reload for development
uv run python main.py

# Or using uvicorn directly with reload
uv run uvicorn main:app --host 0.0.0.0 --port 8001 --reload
```

**Production mode:**
```bash
# Run with multiple workers for production
uv run uvicorn main:app --host 0.0.0.0 --port 8001 --workers 4
```

The application will be available at `http://localhost:8001`

## Docker Deployment

### Build and Run Docker Container

This project includes a multi-stage Dockerfile optimized for production deployment. Use the provided `docker-build.sh` script for easy container management.

#### Build Options

**Build for your current architecture:**
```bash
# Build production image for current architecture
./docker-build.sh

# Or build for specific architecture
./docker-build.sh amd64   # For Intel/AMD processors
./docker-build.sh arm64   # For Apple Silicon (M1/M2)
```

**Build for multiple architectures:**
```bash
# Build for both AMD64 and ARM64 using buildx
./docker-build.sh multi
```

#### Running Docker Containers

**Run production container:**
```bash
# Make sure you have a .env file with your configuration
./docker-build.sh run

# Or run specific architecture
./docker-build.sh run amd64
./docker-build.sh run arm64
```

#### Manual Docker Commands

If you prefer not to use the build script:

```bash
# Build production image
docker build -t products-agent:latest .

# Run with environment file
docker run -p 8001:8001 --env-file .env products-agent:latest
```

#### Push to Registry

To push to a container registry:
```bash
# Build and push to your registry
./docker-build.sh push your-registry.com/products-agent

# This will build for multiple architectures and push
```

### Docker Compose (Alternative)

Create a `docker-compose.yml` for easier development:

```yaml
version: '3.8'
services:
  products-agent:
    build: .
    ports:
      - "8001:8001"
    env_file:
      - .env
    volumes:
      - ./logs:/app/logs  # Optional: for log persistence
    depends_on:
      - products-mcp
    networks:
      - products-network

networks:
  products-network:
    driver: bridge
```

Then run with:
```bash
docker-compose up --build
```

## API Endpoints

### Health Check
- **GET** `/health` - Returns application health status and version information

### Authentication Required Endpoints

All endpoints below require a valid JWT Bearer token in the Authorization header.

### Agent Operations
- **POST** `/agent/invoke` - Invoke the ProductsAgent with natural language queries
  - Request body: `{"prompt": "your natural language query here"}`
  - Response: `{"response": "agent response", "success": true}`

## Usage Examples

### Authentication Header
Include the JWT token in the Authorization header for all API calls:

```bash
curl -X POST "http://localhost:8001/agent/invoke" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Show me all products"}'
```

### Natural Language Queries

**List all products:**
```json
{
  "prompt": "List all products in the catalog"
}
```

**Search for specific products:**
```json
{
  "prompt": "Find all laptops or products containing 'laptop'"
}
```

**Create a new product:**
```json
{
  "prompt": "Create a new product called 'MacBook Pro' with price $2499"
}
```

**Update product information:**
```json
{
  "prompt": "Update the price of product with ID 123 to $1999"
}
```

**Delete a product:**
```json
{
  "prompt": "Delete the product with ID 456"
}
```

**Sort products by price:**
```json
{
  "prompt": "Show me all products sorted by price from lowest to highest"
}
```


## API Documentation

Interactive API documentation is automatically available when running the application:

- **Swagger UI**: `http://localhost:8001/docs`
- **ReDoc**: `http://localhost:8001/redoc`
- **OpenAPI JSON**: `http://localhost:8001/openapi.json`

## Integration with Other Components

This application is part of a larger secure agentic architecture:

- **products-web**: Streamlit web interface for user interactions
- **products-mcp**: Model Context Protocol server for database operations
- **Infrastructure**: AWS services, HCP Vault, and Microsoft Entra ID integration

Refer to the main project README for complete architecture and deployment information.

---

**Note**: This application demonstrates secure authentication patterns and agentic workflows with AI models. Ensure proper security configurations for production deployments.
