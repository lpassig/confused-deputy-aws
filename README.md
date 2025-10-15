# 🫆 Secure Agentic Demo: HCP Vault x Bedrock x Entra ID

A comprehensive demonstration of secure agentic capabilities combining Microsoft Entra ID authentication, AWS Bedrock AI, HCP Vault for credential management, and AWS DocumentDB for data persistence.

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
└─────────────────┘   └────────────┘  └────────────┘   └─────────────────┘
```

## 🧩 Component Overview

### 1. **products-web** - Frontend Interface
- **Technology**: Streamlit web application
- **Authentication**: Microsoft Entra ID OAuth2/JWT
- **Purpose**: User interface for interacting with the AI agent
- **Port**: 8501

### 2. **products-agent** - AI Agent API
- **Technology**: FastAPI with AWS Bedrock Nova Pro
- **Authentication**: On-Behalf-Of (OBO) token exchange
- **Purpose**: AI-powered agent that processes user requests
- **Port**: 8001

### 3. **products-mcp** - Data Access Layer
- **Technology**: Model Context Protocol (MCP) server
- **Authentication**: JWT validation with dynamic credentials
- **Purpose**: Secure database operations with HCP Vault integration
- **Port**: 8000

## 🔐 Security Features

- **Multi-layer Authentication**: OAuth2 → OBO → JWT → Vault → Database
- **Dynamic Credentials**: HCP Vault generates temporary database credentials
- **Zero Trust Architecture**: Every request is authenticated and authorized
- **Secure Token Exchange**: On-Behalf-Of flow for service-to-service communication

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured
- Terraform installed
- Docker and Docker Compose
- Access to Microsoft Entra ID tenant

### 1. Deploy Infrastructure
```bash
cd terraform
terraform init
terraform apply
```

### 2. Deploy Applications
```bash
# Set up environment
./export-env.sh aws

# Auto-configure scripts with Terraform outputs
./scripts/auto-configure.sh

# Deploy to bastion host
ssh -i terraform/ai-l0q-bastion-key.pem ubuntu@$(terraform output -raw bastion_public_ip)
cd /home/ubuntu/docker-compose
docker compose up -d
```

### 3. Access Application
Open your browser to: `https://$(terraform output -raw alb_https_url)`

## 🔧 Automated Secret Management

The solution includes automated scripts to handle Azure AD client secret updates that occur during Terraform applies. All scripts now use **centralized configuration** with variables instead of hardcoded values.

### Initial Setup (One-time)
```bash
# Auto-configure scripts with Terraform outputs
./scripts/auto-configure.sh

# Optional: Convert docker-compose files to use variables
./scripts/update-docker-compose-variables.sh
```

### Available Scripts

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

### Automated Workflow Options

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

#### Option 3: Terraform Integration
```bash
# After every terraform apply
terraform apply && ./scripts/terraform-post-apply.sh
```

## 📊 What the Scripts Handle

### Secret Update Process
1. **Compare Secrets**: Terraform output vs container environment
2. **Detect Mismatches**: Identify outdated client secrets
3. **Update Files**: Modify both `.env` files and `docker-compose.yml` hardcoded values
4. **Recreate Containers**: Complete container recreation (not just restart)
5. **Verify Health**: Confirm services are running and healthy

### Health Monitoring
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

### Web Interface Testing
1. Open the application URL
2. Click "Login with Microsoft"
3. Authenticate with your Microsoft Entra ID credentials
4. Start chatting with the ProductsAgent

### Test Queries
```
"list all products"
"show me products under $100"
"create a new product called 'Gaming Headset' priced at $199.99"
"search for laptop products"
"update the laptop price to $1199.99"
"delete the gaming headset"
```

### Expected Results
You should see responses like:
```
Here is the list of all products:

| ID              | Name               | Price  |
|-----------------|--------------------|--------|
| 68ef3f5e0812023112ce5f47 | Laptop            | 1299.99 |
| 68ef3f5e0812023112ce5f48 | Wireless Mouse   | 29.99  |
| 68ef3f5e0812023112ce5f49 | Mechanical Keyboard | 149.99 |
```

## 🔍 Troubleshooting

### Check Service Status
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

### Manual Verification
```bash
# Check container secrets
docker exec products-agent env | grep ENTRA_CLIENT_SECRET
docker exec products-web env | grep CLIENT_SECRET

# Check Terraform outputs
terraform output products_agent_client_secret
terraform output products_web_client_secret
```

### Health Checks
```bash
# Check service health
curl http://localhost:8001/health
curl http://localhost:8501/_stcore/health
curl http://localhost:8000/mcp
```

## 📁 Project Structure

```
confused-deputy-aws/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   └── modules/              # Terraform modules
├── products-web/             # Streamlit frontend
├── products-agent/           # FastAPI AI agent
├── products-mcp/             # MCP server for data access
├── docker-compose/           # Docker Compose configurations
├── scripts/                  # Automated management scripts
│   ├── update-secrets.sh     # Main secret update script
│   ├── check-auth-health.sh  # Health monitoring script
│   ├── terraform-post-apply.sh # Terraform hook
│   └── README.md            # Script documentation
└── export-env.sh            # Environment setup script
```

## ✅ Benefits

1. **Zero Manual Intervention**: No more manual secret updates
2. **Proactive Monitoring**: Detects issues before they impact users
3. **Automatic Recovery**: Self-healing system that fixes issues automatically
4. **Clear Reporting**: Detailed logs of what was updated and why
5. **Terraform Integration**: Seamless workflow integration
6. **Production Ready**: Robust error handling and verification

## 🎉 Result

**Before**: Manual intervention required every time Terraform regenerates secrets
**After**: Fully automated system that handles secret updates transparently

The recurring authentication issues are now completely solved with a production-ready automated solution! 🚀

## 📚 Additional Resources

- [Microsoft Entra ID Documentation](https://docs.microsoft.com/en-us/azure/active-directory/)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [HCP Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Model Context Protocol (MCP) Specification](https://modelcontextprotocol.io/)
- [Streamlit Documentation](https://docs.streamlit.io/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)