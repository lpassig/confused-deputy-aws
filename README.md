# Secure Agentic Application with AWS, HCP Vault, and Microsoft Entra ID

A comprehensive demonstration of secure agentic workflows that addresses the **Confused Deputy problem** through end-to-end authentication and authorization using OAuth2, HCP Vault, and AWS services. This solution showcases a production-ready, zero-trust architecture for AI/ML workloads with intelligent agents powered by AWS Bedrock.

## Overview

This repository demonstrates a **secure agentic application** that integrates multiple AWS services, Microsoft Entra ID, and HashiCorp Vault to create a zero-trust architecture for AI/ML workloads. The solution provides:

### Key Features

- 🔐 **Zero Trust Architecture**: Every component validates and authorizes requests
- 🔑 **Dynamic Secret Management**: Short-lived, user role-specific database credentials via HCP Vault
- 👥 **Policy-Based Access Control**: Microsoft Entra ID groups mapped to Vault policies
- 🔄 **Secure Token Propagation**: End-to-end JWT validation and delegation
- 🤖 **Agentic Intelligence**: AI-powered product management using AWS Bedrock Nova Pro
- 🏢 **Multi-tenancy Support**: User and group-based data isolation
- 📊 **Audit Trail**: Comprehensive logging and monitoring

## Architecture

### Component Overview

The application consists of three main components that work together to provide secure agentic capabilities:

```
┌─────────────────┐     ┌─────────────────┐            ┌─────────────────┐
│                 │     │                 │            │                 │
│  products-web   │────▶│ products-agent  │──────────▶ │  products-mcp   │
│   (Frontend)    │     │  (Agent API)    │            │  (MCP Server)   │
│  Streamlit UI   │     │  FastAPI + AI   │            │ Data Access     │
└─────────────────┘     └─────────────────┘            └─────────────────┘
         │                   │          │                   │
         │ OAuth2/JWT        │ OBO      │ LLM               │ Dynamic DB Creds
         │                   │          │                   │
         ▼                   ▼          ▼                   ▼
┌─────────────────┐   ┌────────────┐  ┌────────────┐   ┌─────────────────┐
│ Microsoft       │   │ Microsoft  │  │ AWS        │   │   HCP Vault     │
│ Entra ID        │   │ Entra ID   │  │ Bedrock    │   │ + DocumentDB    │
└─────────────────┘   └────────────┘  └────────────┘   └─────────────────┘
```

### Application Components

1. **products-web**: Streamlit-based web interface with Microsoft Entra ID OAuth authentication
2. **products-agent**: FastAPI service with AI agent capabilities using AWS Bedrock Nova Pro model
3. **products-mcp**: Model Context Protocol server for secure database operations with dynamic credentials

### Infrastructure Components

- **HCP Vault**: Centralized secrets management and identity-based authentication
- **AWS DocumentDB**: MongoDB-compatible database for product data
- **Microsoft Entra ID**: Identity provider and OAuth/JWT authentication
- **AWS Bedrock**: AI/ML services with Nova Pro foundation model
- **AWS Infrastructure**: VPC, security groups, bastion host, and networking

## Quick Start

### 1. Infrastructure Setup

Deploy the complete infrastructure using Terraform:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

📖 **For detailed infrastructure setup instructions, see [terraform/README.md](./terraform/README.md)**

### 2. Environment Configuration

Generate environment files for your deployment target:

```bash
# Generate .env files for local development (no Docker)
./terraform/export-env.sh local

# Generate .env files for local Docker Compose
./terraform/export-env.sh docker

# Generate .env files for AWS deployment
./terraform/export-env.sh aws
```

**Environment Options:**
- **`local`**: Run applications directly on local machine without containers
- **`docker`**: Run applications using Docker Compose on local machine
- **`aws`**: Run applications using Docker Compose on AWS bastion host

### 3. Container Images (Required for Docker Deployments)

If using Docker (local Docker Compose or AWS deployment), build and push container images:

```bash
# Build and push products-web image
cd products-web
./docker-build.sh multi
./docker-build.sh push your-registry.com/products-web

# Build and push products-agent image  
cd ../products-agent
./docker-build.sh multi
./docker-build.sh push your-registry.com/products-agent

# Build and push products-mcp image
cd ../products-mcp
./docker-build.sh multi  
./docker-build.sh push your-registry.com/products-mcp
```

**Note**: Update the image references in the docker-compose files to point to your container registry.

## Deployment Options

### Option 1: Local Development (No Docker)

Run all applications directly on your local machine for development:

```bash
# Start products-mcp server
cd products-mcp
source .venv/bin/activate
uv run python server.py

# Start products-agent API (in new terminal)
cd products-agent  
source .venv/bin/activate
uv run uvicorn main:app --host 0.0.0.0 --port 800

# Start products-web interface (in new terminal)
cd products-web
source .venv/bin/activate
uv run streamlit run app.py
```

**Access Points:**
- Web Interface: http://localhost:8501

### Option 2: Local Docker Compose

Run all applications using Docker Compose on your local machine:

```bash
# Ensure you've generated docker environment files
./terraform/export-env.sh docker

# Start all services with Docker Compose
cd docker-compose
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

**Access Points:**
- Web Interface: http://localhost:8501


### Option 3: AWS Deployment

Deploy applications to the AWS bastion host using Docker Compose:

```bash
# Generate AWS environment files
./terraform/export-env.sh aws

# Copy docker-compose files to bastion host
BASTION_IP=$(terraform output -raw bastion_public_ip)
BASTION_KEY=$(terraform output -raw bastion_ssh_key_path)

# Copy all docker-compose files recursively to bastion
scp -i $BASTION_KEY -r docker-compose/ ubuntu@$BASTION_IP:~/

# Connect to bastion host
ssh -i $BASTION_KEY ubuntu@$BASTION_IP

# On bastion host: Start services
cd docker-compose

# Update .env file as below:
target=
platform=linux/amd64
tag=latest

# Start applications
docker-compose up -d

# View logs
docker-compose logs -f
```

**Access Points:**
- Web Interface: https://your-alb-domain.com (via Application Load Balancer)

## Application Usage

### Authentication Flow

1. **User Login**: Navigate to the web interface and click "Login with Microsoft"
2. **OAuth Redirect**: User is redirected to Microsoft Entra ID for authentication
3. **Token Exchange**: Application receives JWT tokens and validates them
4. **Agent Access**: Authenticated requests are made to the ProductsAgent API
5. **Database Operations**: Agent uses dynamic credentials from Vault to access DocumentDB

### Product Management Queries

The AI agent supports natural language queries for product management:

```
"Show me all products"
"Find laptops under $1500" 
"Create a new product called MacBook Air priced at $999"
"Update product ID 123 to cost $1299"
"Delete the product named 'Old Monitor'"
"Sort products by price from lowest to highest"
```

### Security Features in Action

- **Dynamic Secrets**: Database credentials are generated on-demand with TTL
- **Token Validation**: Every API call validates JWT signatures and claims
- **Group-Based Access**: User permissions based on Entra ID group membership
- **Audit Logging**: All operations are logged for security and compliance

## Configuration

### Environment Files Generated

The `export-env.sh` script generates environment files for each component:

- **products-web/.env**: Frontend OAuth configuration and API endpoints
- **products-agent/.env**: JWT validation, Bedrock, and MCP configuration  
- **products-mcp/.env**: Database connection and Vault authentication


## Monitoring and Management

### Logs and Monitoring
```bash
# Docker Compose logs
docker compose logs -f [service-name]

# AWS deployment logs
ssh -i $BASTION_KEY ubuntu@$BASTION_IP

cd docker-compose
docker compose logs -f [server-name]
```

### Vault Operations

```bash
# Connect to Vault
export VAULT_ADDR=$(terraform output -raw vault_public_endpoint_url)
export VAULT_TOKEN=$(terraform output -raw vault_admin_token)

# Check authentication methods
vault auth list

# View database secrets
vault read database/creds/readonly-role
```

## Development Workflow

### Prerequisites for Development

Each component has specific setup requirements. See individual README files:
- [products-web/README.md](./products-web/README.md)
- [products-agent/README.md](./products-agent/README.md)
- [products-mcp/README.md](./products-mcp/README.md)

### Testing the Complete Flow

1. **Deploy Infrastructure**: Use Terraform to create AWS, HCP, and Entra ID resources
2. **Generate Configuration**: Run `export-env.sh` for your target environment
3. **Start Services**: Use your preferred deployment option (local, docker, aws)
4. **Access Web UI**: Navigate to the web interface and authenticate
5. **Test Agent**: Try natural language queries for product operations
6. **Verify Security**: Check Vault for dynamic secrets and audit logs

## Cleanup

### Application Cleanup

```bash
# Stop local services (Ctrl+C for each service)

# Stop Docker Compose services
docker-compose down

# Clean up AWS deployment
ssh -i $BASTION_KEY ubuntu@$BASTION_IP "cd docker-compose && docker-compose down"
```

### Infrastructure Cleanup

```bash
cd terraform
terraform destroy
```

**⚠️ Important**: This will destroy all infrastructure resources including databases. Ensure you have backups if needed.

## The Confused Deputy Problem

This solution specifically addresses the **Confused Deputy problem** in distributed systems where:

- **Problem**: Services acting on behalf of users might exceed their intended permissions
- **Solution**: Each service validates user identity and only performs authorized operations
- **Implementation**: JWT token propagation with scoped permissions and dynamic secrets

### Security Patterns Demonstrated

1. **Identity Propagation**: User identity flows through all services
2. **Least Privilege**: Each service gets minimal required permissions  
3. **Dynamic Credentials**: Database access uses short-lived, scoped credentials
4. **Audit Trail**: All operations are logged with user context
5. **Policy Enforcement**: Vault policies control access based on user groups

### Traditional Challenge

In conventional agentic architectures, a backend service (the "deputy") often uses its own elevated privileges to access resources on behalf of users. This creates several security risks:

1. **Privilege Escalation**: Users can access data beyond their authorization level
2. **Blast Radius**: Compromise of the deputy service exposes all data
3. **Audit Gaps**: Difficult to trace actions back to the actual user
4. **Policy Drift**: Static permissions become stale and overprivileged

### Example Vulnerable Flow

```
User → Agent API → Tool (uses admin DB creds) -> Database
                     ↑
         privileged permissions
```

### Secure Solution

```
User → UI (JWT) → Agent (on-behalf-of JWT) → MCP (Vault auth) → DB (dynamic creds)
  ↑      ↑              ↑                      ↑                    ↑
Identity  Validation    Delegation           Policy Enforcement   Least Privilege
```

## Security Design Patterns

### 1. Token Delegation Pattern

Instead of using service accounts, each request carries the user's identity through the entire call chain:

- **Frontend**: User JWT from Entra ID
- **Agent API**: On-behalf-of JWT (delegated)
- **MCP Server**: Validated and mapped to Vault policies

### 2. Dynamic Secret Pattern

Database credentials are:
- **Short-lived** (typically 1-24 hours)
- **User/group-specific** (based on Entra ID groups)
- **Just-in-time** (generated when needed)
- **Automatically rotated** (by Vault)

### 3. Policy as Code Pattern

```hcl
# Example Vault Policy for ReadOnly group
path "database/creds/readonly-role" {
  capabilities = ["read"]
}

path "database/static-creds/readonly-*" {
  capabilities = ["read"]
}
```

### 4. Zero Trust Validation

Every component validates incoming tokens:
- **JWT signature verification**
- **Token expiry checks**
- **Audience validation**
- **Issuer verification**
- **Group claim extraction**

## Components

### products-web (UI Layer)

**Technology Stack:**
- Streamlit frontend
- Microsoft Authentication Library (MSAL)
- OAuth2 Authorization Code Flow with PKCE

**Key Features:**
- Secure authentication with Entra ID
- Token management and refresh
- Secure HTTP client with automatic token injection
- Error handling and user feedback

### products-agent (Agent API)

**Technology Stack:**
- Python with FastAPI
- AWS Strands SDK for agentic workflows
- JWT validation libraries

**Key Features:**
- JWT token validation and on-behalf-of exchange
- Integration with AWS Bedrock
- RESTful API endpoints

### products-mcp (MCP Server)

**Technology Stack:**
- Python with FastMCP framework
- HVAC (HashiCorp Vault API client)
- PyMongo for DocumentDB connectivity
- JWT validation and claims processing

**Key Features:**
- Vault authentication using JWT auth method
- Dynamic secret retrieval
- Group-based policy enforcement
- Database connection pooling

## End-to-End Secure Flow

### Detailed Authentication Flow

![End-to-End Secure Flow](images/)

### Token Validation Process

1. **Signature Verification**: Validate JWT signature using Entra ID public keys
2. **Claims Validation**: Check issuer, audience, expiry, and custom claims
3. **Group Extraction**: Extract Entra ID security groups from token claims
4. **Policy Mapping**: Map groups to corresponding Vault policies
5. **Access Decision**: Allow/deny based on policy evaluation

---

**⚠️ Important**: This infrastructure creates billable resources in HCP, AWS, and Azure. Monitor costs and destroy resources when not needed for development/testing purposes.
