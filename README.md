# 🫆 Secure Agentic Demo: HCP Vault x Bedrock x Entra ID

A comprehensive demonstration of secure agentic capabilities combining Microsoft Entra ID authentication, AWS Bedrock AI, HCP Vault for credential management, and AWS DocumentDB for data persistence. This solution specifically addresses the **Confused Deputy Problem** in distributed systems through secure token delegation and dynamic credential management.

## 🎯 The Confused Deputy Problem

### **Problem Definition**
In traditional agentic architectures, a backend service (the "deputy") often uses its own elevated privileges to access resources on behalf of users. This creates several critical security risks:

- **Privilege Escalation**: Users can access data beyond their authorization level
- **Blast Radius**: Compromise of the deputy service exposes all data
- **Audit Gaps**: Difficult to trace actions back to the actual user
- **Policy Drift**: Static permissions become stale and overprivileged

### **Vulnerable Flow Example**
```
User → Agent API → Tool (uses admin DB creds) → Database
                    ↑
        privileged permissions
```

### **Our Secure Solution**
```
User → UI (JWT) → Agent (on-behalf-of JWT) → MCP (Vault auth) → DB (dynamic creds)
  ↑      ↑              ↑                      ↑                    ↑
Identity  Validation    Delegation           Policy Enforcement   Least Privilege
```

### **Security Patterns Implemented**

#### 1. **Token Delegation Pattern**
Instead of using service accounts, each request carries the user's identity through the entire call chain:
- **Frontend**: User JWT from Entra ID
- **Agent API**: On-behalf-of JWT (delegated)
- **MCP Server**: Validated and mapped to Vault policies

#### 2. **Dynamic Secret Pattern**
Database credentials are:
- **Short-lived** (typically 1-24 hours)
- **User/group-specific** (based on Entra ID groups)
- **Just-in-time** (generated when needed)
- **Automatically rotated** (by Vault)

#### 3. **Policy as Code Pattern**
```hcl
# Example Vault Policy for ReadOnly group
path "database/creds/readonly-role" {
  capabilities = ["read"]
}

path "database/static-creds/readonly-*" {
  capabilities = ["read"]
}
```

#### 4. **Zero Trust Validation**
Every component validates incoming tokens:
- JWT signature verification
- Token expiry checks
- Audience validation
- Issuer verification
- Group claim extraction

## 🏗️ Architecture Overview

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
└─────────────────┘   └────────────┘   └────────────┘   └─────────────────┘
```

## 🔐 Why HCP Vault?

### **Traditional Database Access Problems**
```python
# ❌ Traditional approach - Static credentials
DATABASE_URL = "mongodb://admin:password123@db.example.com:27017/products"
# Problems:
# - Same credentials for all users
# - Credentials never rotate
# - Admin-level access for all operations
# - No audit trail of who accessed what
```

### **HCP Vault Solution**
```python
# ✅ Vault approach - Dynamic credentials
def get_database_credentials(user_jwt):
    # 1. Validate user JWT
    user_info = validate_jwt(user_jwt)
    
    # 2. Authenticate with Vault using user identity
    vault_token = vault.auth.jwt(user_jwt)
    
    # 3. Generate user-specific database credentials
    creds = vault.read(f"database/creds/{user_info.role}")
    
    # 4. Return short-lived, scoped credentials
    return {
        "username": creds["username"],  # e.g., "v-token-readonly-abc123"
        "password": creds["password"],  # e.g., "A1b2C3d4E5f6..."
        "ttl": creds["lease_duration"]  # e.g., 3600 seconds
    }
```

### **Vault Benefits**
1. **Dynamic Credentials**: Each user gets unique DB credentials
2. **Automatic Rotation**: Credentials expire and rotate automatically
3. **Least Privilege**: Users only get permissions they need
4. **Audit Trail**: Every credential generation is logged
5. **Policy Enforcement**: Centralized access control
6. **Zero Static Secrets**: No hardcoded database passwords

## 🧩 Component Overview

### 1. **products-web** - Frontend Interface
- **Technology**: Streamlit web application
- **Authentication**: Microsoft Entra ID OAuth2/JWT
- **Purpose**: User interface for interacting with the AI agent
- **Port**: 8501
- **Security**: Validates user JWT, exchanges for agent token

### 2. **products-agent** - AI Agent API
- **Technology**: FastAPI with AWS Bedrock Nova Pro
- **Authentication**: On-Behalf-Of (OBO) token exchange
- **Purpose**: AI-powered agent that processes user requests
- **Port**: 8001
- **Security**: Delegates user identity to MCP server

### 3. **products-mcp** - Data Access Layer
- **Technology**: Model Context Protocol (MCP) server
- **Authentication**: JWT validation with dynamic credentials
- **Purpose**: Secure database operations with HCP Vault integration
- **Port**: 8000
- **Security**: Generates dynamic DB credentials per user

## 🔄 Authentication Flow

### **Step-by-Step Authentication Process**

#### 1. **User Login (Frontend)**
```mermaid
sequenceDiagram
    participant U as User
    participant W as ProductsWeb
    participant E as Entra ID
    
    U->>W: Click "Login with Microsoft"
    W->>E: Redirect to OAuth2 login
    E->>U: Show login form
    U->>E: Enter credentials
    E->>W: Return authorization code
    W->>E: Exchange code for JWT
    E->>W: Return user JWT
    W->>W: Store JWT in session
```

#### 2. **Agent Request (OBO Flow)**
```mermaid
sequenceDiagram
    participant W as ProductsWeb
    participant A as ProductsAgent
    participant E as Entra ID
    
    W->>A: POST /agent/invoke with user JWT
    A->>E: OBO token exchange request
    Note over A,E: client_credentials + user JWT
    E->>A: Return agent-scoped JWT
    A->>A: Validate agent JWT
    A->>A: Process request with Bedrock
```

#### 3. **Database Access (Dynamic Credentials)**
```mermaid
sequenceDiagram
    participant A as ProductsAgent
    participant M as ProductsMCP
    participant V as HCP Vault
    participant D as DocumentDB
    
    A->>M: POST /mcp with agent JWT
    M->>V: Authenticate with JWT
    V->>M: Return Vault token
    M->>V: Request database credentials
    V->>M: Return dynamic DB credentials
    M->>D: Connect with dynamic credentials
    D->>M: Return query results
    M->>A: Return data
```

### **Token Scopes and Permissions**

#### **User JWT Scopes**
```json
{
  "aud": "api://docloudright.onmicrosoft.com/products-web",
  "scp": "openid profile email",
  "groups": ["Products.ReadOnly", "Products.ReadWrite"],
  "sub": "user-12345"
}
```

#### **Agent JWT Scopes**
```json
{
  "aud": "api://docloudright.onmicrosoft.com/products-agent",
  "scp": "api://docloudright.onmicrosoft.com/products-mcp/Products.Read",
  "oid": "user-12345",
  "sub": "agent-service"
}
```

#### **Vault Policy Mapping**
```hcl
# ReadOnly users get limited database access
path "database/creds/readonly-role" {
  capabilities = ["read"]
  required_parameters = ["groups"]
  allowed_parameters = {
    "groups" = ["Products.ReadOnly"]
  }
}

# ReadWrite users get full database access
path "database/creds/readwrite-role" {
  capabilities = ["read", "create", "update", "delete"]
  required_parameters = ["groups"]
  allowed_parameters = {
    "groups" = ["Products.ReadWrite"]
  }
}
```

## 🚀 Deployment Guide

### **Prerequisites**
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Docker and Docker Compose installed
- Access to Microsoft Entra ID tenant
- HCP Vault account (free tier available)

### **Step 1: Infrastructure Deployment**

#### **Configure Terraform Variables**
```bash
# Copy and edit the example file
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit with your values
nano terraform/terraform.tfvars
```

**Required Variables:**
```hcl
# AWS Configuration
aws_region = "eu-central-1"
aws_account_id = "YOUR_AWS_ACCOUNT_ID"

# Microsoft Entra ID Configuration
tenant_id = "YOUR_TENANT_ID"
ad_user_password = "YOUR_AD_USER_PASSWORD"

# DocumentDB Configuration
docdb_master_username = "YOUR_DB_USERNAME"
docdb_master_password = "YOUR_DB_PASSWORD"

# HCP Vault Configuration
hcp_vault_tier = "dev"  # or "standard" for production
```

#### **Deploy Infrastructure**
```bash
cd terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply
```

**What Gets Created:**
- VPC with public/private subnets
- Bastion host with Application Load Balancer
- DocumentDB cluster with security groups
- HCP Vault cluster
- Azure AD application registrations
- ECR repositories for container images

### **Step 2: Application Deployment**

#### **Build and Push Container Images**
```bash
# Build and push all images to ECR
./deploy-ecr.sh
```

#### **Deploy to Bastion Host**
```bash
# Get bastion host IP
BASTION_IP=$(terraform output -raw bastion_public_ip)

# Copy deployment files
scp -i terraform/ai-l0q-bastion-key.pem -r docker-compose/ ubuntu@$BASTION_IP:/home/ubuntu/
scp -i terraform/ai-l0q-bastion-key.pem docker-compose-unified.yml ubuntu@$BASTION_IP:/home/ubuntu/docker-compose/

# SSH into bastion host
ssh -i terraform/ai-l0q-bastion-key.pem ubuntu@$BASTION_IP

# On bastion host, start services
cd /home/ubuntu/docker-compose
docker compose -f docker-compose-unified.yml up -d
```

### **Step 3: Post-Deployment Configuration**

#### **Run Post-Deployment Fixes**
```bash
# On bastion host
./post-deploy-fix.sh
```

#### **Configure Automated Secret Management**
```bash
# Auto-configure scripts with Terraform outputs
./scripts/auto-configure.sh

# Optional: Convert docker-compose files to use variables
./scripts/update-docker-compose-variables.sh
```

### **Step 4: Access Application**
```bash
# Get application URL
terraform output alb_https_url

# Open in browser
open https://$(terraform output -raw alb_https_url)
```

## 🔧 Automated Secret Management

The solution includes automated scripts to handle Azure AD client secret updates that occur during Terraform applies. All scripts now use **centralized configuration** with variables instead of hardcoded values.

### **Why Automated Secret Management?**

**Problem**: Azure AD application passwords are regenerated every time you run `terraform apply`, but Docker containers continue using the old client secrets, causing authentication failures.

**Solution**: Automated scripts that detect secret mismatches and update containers automatically.

### **Initial Setup (One-time)**
```bash
# Auto-configure scripts with Terraform outputs
./scripts/auto-configure.sh

# Optional: Convert docker-compose files to use variables
./scripts/update-docker-compose-variables.sh
```

### **Available Scripts**

#### `update-secrets.sh` - Main Update Script
```bash
# Fix authentication issues immediately
./scripts/update-secrets.sh
```

#### `check-auth-health.sh` - Health Monitor
```bash
# Check system health and fix issues if found
./scripts/check-auth-health.sh
```

#### `terraform-post-apply.sh` - Terraform Hook
```bash
# Run after terraform apply
terraform apply && ./scripts/terraform-post-apply.sh
```

### **Automated Workflow Options**

#### Option 1: Manual Monitoring
```bash
# Check every 5 minutes
while true; do
    ./scripts/check-auth-health.sh
    sleep 300
done
```

#### Option 2: Cron Job
```bash
# Add to crontab for automatic monitoring
*/5 * * * * /path/to/confused-deputy-aws/scripts/check-auth-health.sh
```

#### Option 3: Systemd Service (Recommended for Production)
```bash
# Copy service file
sudo cp scripts/auth-monitor.service /etc/systemd/system/

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable auth-monitor.service
sudo systemctl start auth-monitor.service

# Check status
systemctl status auth-monitor.service
```

## 📊 What the Scripts Handle

### **Secret Update Process**
1. **Compare Secrets**: Terraform output vs container environment
2. **Detect Mismatches**: Identify outdated client secrets
3. **Update Files**: Modify both `.env` files and `docker-compose.yml` hardcoded values
4. **Recreate Containers**: Complete container recreation (not just restart)
5. **Verify Health**: Confirm services are running and healthy

### **Health Monitoring**
1. **Log Analysis**: Check recent logs for authentication errors
2. **HTTP Health**: Verify service endpoints are responding
3. **Auto-Fix**: Trigger secret updates when issues detected
4. **Reporting**: Provide clear status messages

## 🎯 Services Monitored

- **ProductsAgent** (`${PRODUCTS_AGENT_CLIENT_ID}`)
  - Environment: `ENTRA_CLIENT_SECRET`
  - Health: `http://localhost:8001/health`
  - Log Pattern: `invalid_client|AADSTS7000215|Token exchange failed`

- **ProductsWeb** (`${PRODUCTS_WEB_CLIENT_ID}`)
  - Environment: `CLIENT_SECRET`
  - Health: `http://localhost:8501/_stcore/health`
  - Log Pattern: `invalid_client|AADSTS7000215|Authentication failed`

## 🧪 Testing the Application

### **Web Interface Testing**
1. Open the application URL: `https://$(terraform output -raw alb_https_url)`
2. Click "Login with Microsoft" and authenticate with your Entra ID user
3. Once authenticated, try interacting with the AI agent

### **Test Queries**
```
"list all products"
"show me products under $100"
"create a new product called 'Gaming Headset' priced at $199.99"
"search for laptop products"
"update the laptop price to $1199.99"
"delete the gaming headset"
```

### **Expected Results**
You should see responses like:
```
Here is the list of all products:

| ID              | Name               | Price  |
|-----------------|--------------------|--------|
| 68ef3f5e0812023112ce5f47 | Laptop            | 1299.99 |
| 68ef3f5e0812023112ce5f48 | Wireless Mouse   | 29.99  |
| 68ef3f5e0812023112ce5f49 | Mechanical Keyboard | 149.99 |
```

### **API Testing (ProductsAgent)**
You can test the ProductsAgent API directly using `curl` or a tool like Postman/Insomnia.

1. **Get an access token**: Authenticate via the web UI and inspect network requests, or use a tool like MSAL
2. **Invoke agent**:
   ```bash
   curl -X POST "https://$(terraform output -raw alb_https_url)/agent/invoke" \
        -H "Authorization: Bearer <YOUR_ACCESS_TOKEN>" \
        -H "Content-Type: application/json" \
        -d '{ "prompt": "list all products" }'
   ```
3. **Check health**:
   ```bash
   curl https://$(terraform output -raw alb_https_url)/health
   ```

### **API Testing (ProductsMCP)**
The ProductsMCP API is internal and not directly exposed. It's called by the ProductsAgent.

## 🔍 Troubleshooting

### **Check Service Status**
```bash
# SSH into bastion host
ssh -i terraform/ai-l0q-bastion-key.pem ubuntu@$(terraform output -raw bastion_public_ip)

# Check container status
docker ps

# Check service logs
docker logs products-agent --tail=20
docker logs products-mcp --tail=20
docker logs products-web --tail=20
```

### **Manual Verification**
```bash
# Check container secrets
docker exec products-agent env | grep ENTRA_CLIENT_SECRET
docker exec products-web env | grep CLIENT_SECRET

# Check Terraform outputs
terraform output products_agent_client_secret
terraform output products_web_client_secret
```

### **Health Checks**
```bash
# Check service health
curl http://localhost:8001/health
curl http://localhost:8501/_stcore/health
curl http://localhost:8000/mcp
```

### **Common Issues and Solutions**

#### **Authentication Failures**
```bash
# Check for secret mismatches
./scripts/check-auth-health.sh

# Manually update secrets
./scripts/update-secrets.sh
```

#### **Database Connection Issues**
```bash
# Check Vault connectivity
curl -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/sys/health

# Check DocumentDB connectivity
telnet $(terraform output -raw docdb_endpoint) 27017
```

#### **Bedrock API Issues**
```bash
# Check Bedrock permissions
aws bedrock list-foundation-models --region eu-central-1

# Check IAM policy
aws iam get-policy-version --policy-arn $(terraform output -raw bastion_iam_policy_arn) --version-id v1
```

## 📁 Project Structure

```
confused-deputy-aws/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output definitions
│   ├── providers.tf          # Provider configurations
│   ├── export-env.sh         # Environment setup script
│   └── modules/              # Terraform modules
│       ├── aws-networking/   # VPC, subnets, security groups
│       ├── aws-documentdb/   # DocumentDB cluster
│       ├── bastion/          # Bastion host and ALB
│       ├── hcp-vault/        # HCP Vault cluster
│       ├── azure-ad-app/     # Azure AD applications
│       ├── vault-auth/       # Vault authentication setup
│       └── ecr/              # ECR repositories
├── products-web/             # Streamlit frontend
│   ├── app.py               # Main application
│   ├── docker-build.sh      # Build script
│   └── .env.example         # Environment template
├── products-agent/           # FastAPI AI agent
│   ├── main.py              # Main application
│   ├── products_agent.py    # Agent logic
│   ├── auth/                # Authentication modules
│   ├── docker-build.sh      # Build script
│   └── .env.example         # Environment template
├── products-mcp/             # MCP server for data access
│   ├── server.py            # MCP server
│   ├── vault_client.py      # Vault integration
│   ├── db_utils.py          # Database utilities
│   ├── docker-build.sh      # Build script
│   └── .env.example         # Environment template
├── docker-compose/           # Docker Compose configurations
│   ├── docker-compose.yml   # Main compose file
│   ├── products-web/        # Web service config
│   ├── products-agent/      # Agent service config
│   └── products-mcp/        # MCP service config
├── scripts/                  # Automated management scripts
│   ├── update-secrets.sh     # Main secret update script
│   ├── check-auth-health.sh  # Health monitoring script
│   ├── terraform-post-apply.sh # Terraform hook
│   ├── auto-configure.sh    # Auto-configuration script
│   ├── setup.sh             # Setup script
│   └── README.md            # Script documentation
├── docker-compose-unified.yml # Unified compose file
├── deploy-ecr.sh            # ECR deployment script
├── post-deploy-fix.sh       # Post-deployment fixes
├── BEDROCK_CONFIGURATION.md # Bedrock setup guide
└── README.md                # This file
```

## ✅ Benefits

### **Security Benefits**
1. **Zero Static Secrets**: No hardcoded database passwords
2. **Dynamic Credentials**: Each user gets unique, temporary credentials
3. **Least Privilege**: Users only get permissions they need
4. **Audit Trail**: Every action is traceable to a specific user
5. **Automatic Rotation**: Credentials expire and rotate automatically

### **Operational Benefits**
1. **Zero Manual Intervention**: No more manual secret updates
2. **Proactive Monitoring**: Detects issues before they impact users
3. **Automatic Recovery**: Self-healing system that fixes issues automatically
4. **Clear Reporting**: Detailed logs of what was updated and why
5. **Terraform Integration**: Seamless workflow integration
6. **Production Ready**: Robust error handling and verification

### **Developer Benefits**
1. **Clear Architecture**: Well-defined service boundaries
2. **Comprehensive Documentation**: Detailed setup and troubleshooting guides
3. **Automated Testing**: Built-in health checks and monitoring
4. **Easy Deployment**: One-command infrastructure and application deployment
5. **Scalable Design**: Can be extended for additional services and users

## 🎉 Result

**Before**: Manual intervention required every time Terraform regenerates secrets, static database credentials, no audit trail, privilege escalation risks

**After**: Fully automated system that handles secret updates transparently, dynamic user-specific credentials, complete audit trail, zero privilege escalation

The recurring authentication issues are now completely solved with a production-ready automated solution that addresses the Confused Deputy Problem! 🚀

## 📚 Additional Resources

- [Microsoft Entra ID Documentation](https://docs.microsoft.com/en-us/azure/active-directory/)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [HCP Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Model Context Protocol (MCP) Specification](https://modelcontextprotocol.io/)
- [Streamlit Documentation](https://docs.streamlit.io/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## 🤝 Contributing

This project demonstrates secure agentic architecture patterns. Contributions are welcome for:
- Additional security patterns
- New authentication methods
- Enhanced monitoring capabilities
- Additional service integrations

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.