# Secure Agentic Infrastructure with Terraform

This Terraform configuration deploys a comprehensive secure infrastructure for running agentic AI applications with end-to-end authentication, authorization, and zero-trust architecture principles. The infrastructure integrates HashiCorp Cloud Platform (HCP) Vault, AWS services, Microsoft Entra ID, and AWS Bedrock to create a production-ready environment for secure AI workloads.

## Architecture Overview

The infrastructure consists of six main components that work together to provide a secure, scalable platform:

1. **HCP Vault Cluster**: Centralized secrets management and identity-based authentication
2. **AWS Networking**: VPC with public/private subnets and secure connectivity to HCP
3. **AWS DocumentDB**: MongoDB-compatible database for application data storage
4. **Bastion Host**: Secure access point with application deployment and management tools
5. **Microsoft Entra ID Applications**: OAuth/JWT authentication and authorization
6. **Vault Authentication**: JWT-based authentication bridge between Entra ID and Vault

## Prerequisites

Before deploying this infrastructure, ensure you have the following prerequisites configured:

### 1. HashiCorp Cloud Platform (HCP)

- **HCP Account**: Active account with billing enabled
- **Service Principal**: Create an HCP service principal with the following permissions:
  - `Contributor` role on the HCP project
  - Ability to create and manage HVN and Vault clusters
- **Client Credentials**: Note the Client ID and Client Secret for the service principal

```bash
# Set HCP credentials (required for deployment)
export HCP_CLIENT_ID="your-hcp-client-id"
export HCP_CLIENT_SECRET="your-hcp-client-secret"
```

### 2. AWS Configuration

- **AWS Account**: Active AWS account with appropriate permissions
- **IAM Permissions**: Ensure your AWS credentials have permissions for:
  - VPC management (create/modify/delete VPCs, subnets, route tables, gateways)
  - EC2 management (instances, security groups, key pairs)
  - DocumentDB cluster management
  - Application Load Balancer management
  - Certificate Manager (for SSL certificates)
- **AWS CLI**: Configured with appropriate credentials

```bash
# Configure AWS CLI (required for deployment)
aws configure
```

### 3. Microsoft Entra ID (Azure AD) Configuration

- **Azure AD Tenant**: Access to an Azure AD tenant with administrative privileges
- **Service Principal**: Create a service principal with the following permissions:
  - **Microsoft Graph API Permissions**:
    - `Application.ReadWrite.All` (to create and manage app registrations)
    - `ConsentRequest.ReadWrite.All` (to approve or deny app consent requests and approvals without a signed-in user)
    - `Domain.Read.All` (to read domain information)
    - `Group.ReadWrite.All` (to read and write group information)
    - `User.ReadWrite.All` (and write to reada and write user information)
    - `Directory.Read.All` (for directory access)
  - **Azure Active Directory Graph API Permissions**:
    - `Directory.ReadWrite.All` (legacy permissions for certain operations)
- **Custom Domain**: Configured custom domain in your Azure AD tenant (required for certain operations)
- **Admin Consent**: Grant admin consent for the service principal permissions

```bash
# Set Azure credentials (required for deployment)
export AZURE_TENANT_ID="your-azure-tenant-id"
export AZURE_CLIENT_ID="your-azure-service-principal-client-id"
export AZURE_CLIENT_SECRET="your-azure-service-principal-client-secret"
```

### 4. AWS Bedrock Configuration

- **Model Access**: Enable access to the **Nova Pro model** in the **eu-central-1** region
  
**Important**: This application has been specifically tested with the **Nova Pro model** in the **eu-central-1** region. Enable model access through the AWS Console:

1. Navigate to AWS Bedrock console in **eu-central-1** region
2. Go to "Model Access" in the left sidebar
3. Request access to the **Nova Pro** model
4. Wait for approval (this may take some time)

**Critical**: Nova Pro requires **inference profiles**, not direct model access. The Terraform configuration automatically includes the correct inference profile ARNs and multi-region permissions.

### 5. Update Hardcoded Paths in `export-env.sh`

**Important**: The `export-env.sh` script contains hardcoded paths that must be updated for your environment:

```bash
# Edit the export script
nano export-env.sh
```

**Required Changes:**

1. **Update ROOT_PATH for all environments**:
   ```bash
   # Replace YOUR_USERNAME with your actual username
   ROOT_PATH="/Users/YOUR_USERNAME/docloudright/confused-deputy-aws"
   ```

2. **Update TF_STATE path**:
   ```bash
   export TF_STATE=/Users/YOUR_USERNAME/docloudright/confused-deputy-aws/terraform/terraform.tfstate
   ```

3. **Update Tenant ID** (if using Microsoft Entra ID):
   ```bash
   TENANT_ID=your-tenant-id-here
   JWT_ISSUER=https://login.microsoftonline.com/your-tenant-id-here/v2.0
   ```

### 6. Required Tools

- **Terraform**: Version >= 1.5
- **AWS CLI**: Latest version, properly configured
- **HCP CLI**: For HCP management (optional but recommended)

**Note:** The infrastructure automatically configures ECR permissions for the bastion host, so no additional IAM setup is required for container deployments.

## 🔧 Production Deployment Learnings

**This section documents critical learnings from production deployment that must be addressed:**

### Critical Issues and Solutions

#### 1. Azure AD Client Secret Regeneration

**Issue**: Azure AD client secrets are regenerated every time Terraform applies, breaking existing deployments.

**Impact**: 
- Existing containers lose authentication
- OAuth flows fail with 401 Unauthorized errors
- Application becomes inaccessible

**Solution**: After every `terraform apply`, update client secrets:

```bash
# Get new client secrets from Terraform
cd terraform
PRODUCTS_WEB_SECRET=$(terraform output -raw products_web_client_secret)
PRODUCTS_AGENT_SECRET=$(terraform output -raw products_agent_client_secret)

# Update docker-compose files
sed -i "s/ENTRA_CLIENT_SECRET=.*/ENTRA_CLIENT_SECRET=$PRODUCTS_AGENT_SECRET/" ../docker-compose/products-agent/docker-compose.yml
sed -i "s/CLIENT_SECRET=.*/CLIENT_SECRET=$PRODUCTS_WEB_SECRET/" ../docker-compose/products-web/.env

# Redeploy to update secrets
cd ..
./deploy-ecr.sh deploy
```

#### 2. Nova Pro Inference Profile Requirements

**Issue**: Nova Pro requires inference profiles, not direct model access.

**Error**: `ValidationException: Invocation of model ID amazon.nova-pro-v1:0 with on-demand throughput isn't supported`

**Solution**: Use inference profile ID:

```bash
# Correct configuration
export BEDROCK_MODEL_ID="eu.amazon.nova-pro-v1:0"  # Inference profile ID
export BEDROCK_REGION="eu-central-1"
```

#### 3. Multi-Region IAM Policy Requirements

**Issue**: Nova Pro inference profiles require permissions across multiple regions.

**Error**: `AccessDeniedException: User is not authorized to perform: bedrock:InvokeModel`

**Solution**: Terraform automatically includes all supported regions:

```hcl
# terraform/modules/bastion/alb-resources.tf
resources = [
  # Inference profiles for all supported regions
  "arn:aws:bedrock:eu-central-1:YOUR_AWS_ACCOUNT_ID:inference-profile/eu.amazon.nova-pro-v1:0",
  "arn:aws:bedrock:eu-west-3:YOUR_AWS_ACCOUNT_ID:inference-profile/eu.amazon.nova-pro-v1:0",
  "arn:aws:bedrock:eu-west-1:YOUR_AWS_ACCOUNT_ID:inference-profile/eu.amazon.nova-pro-v1:0",
  "arn:aws:bedrock:eu-north-1:YOUR_AWS_ACCOUNT_ID:inference-profile/eu.amazon.nova-pro-v1:0",
  # Foundation models for all supported regions
  "arn:aws:bedrock:eu-central-1::foundation-model/amazon.nova-pro-v1:0",
  "arn:aws:bedrock:eu-west-3::foundation-model/amazon.nova-pro-v1:0",
  "arn:aws:bedrock:eu-west-1::foundation-model/amazon.nova-pro-v1:0",
  "arn:aws:bedrock:eu-north-1::foundation-model/amazon.nova-pro-v1:0"
]
```

#### 4. OAuth State Mismatch Resolution

**Issue**: Cached Docker images cause OAuth state mismatches.

**Error**: `StreamlitOauthError: STATE DOES NOT MATCH OR OUT OF DATE`

**Solution**: Force rebuild and redeploy:

```bash
# Force rebuild and redeploy
./deploy-ecr.sh build
./deploy-ecr.sh deploy
```

#### 5. JWT Audience Configuration

**Issue**: JWT audience must match the identifier URI, not the client ID.

**Error**: `API Error: Invalid token: Signature verification failed`

**Solution**: Configure JWT audience correctly:

```bash
# ProductsAgent JWT audience should be the identifier URI
JWT_AUDIENCE="api://docloudright.onmicrosoft.com/products-agent"

# ProductsMCP JWT audience should be the client ID
JWT_AUDIENCE="YOUR_PRODUCTS_MCP_CLIENT_ID"
```

#### 6. Hardcoded Values in Docker Compose

**Issue**: Docker Compose files contain hardcoded client IDs, secrets, and URLs.

**Current Hardcoded Values** (must be updated after Terraform apply):

```yaml
# docker-compose/products-agent/docker-compose.yml
environment:
  - ENTRA_CLIENT_ID=YOUR_PRODUCTS_AGENT_CLIENT_ID
  - ENTRA_CLIENT_SECRET=YOUR_PRODUCTS_AGENT_CLIENT_SECRET
  - ENTRA_SCOPE=api://docloudright.onmicrosoft.com/products-mcp/Products.Read api://docloudright.onmicrosoft.com/products-mcp/Products.List api://docloudright.onmicrosoft.com/products-mcp/Products.Write api://docloudright.onmicrosoft.com/products-mcp/Products.Delete
  - ENTRA_TOKEN_URL=https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/token
  - JWKS_URI=https://login.microsoftonline.com/YOUR_TENANT_ID/discovery/v2.0/keys
  - JWT_ISSUER=https://sts.windows.net/YOUR_TENANT_ID/
  - JWT_AUDIENCE=YOUR_PRODUCTS_AGENT_CLIENT_ID
```

#### 7. ECR Region Configuration

**Issue**: ECR login region must match the deployment region.

**Solution**: Deployment script automatically uses correct region:

```bash
# deploy-ecr.sh automatically uses eu-central-1 for ECR login
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.eu-central-1.amazonaws.com
```

#### 8. Environment Variable Precedence

**Issue**: Docker Compose environment variables override .env file variables.

**Solution**: Use `env_file` for base configuration and `environment` for overrides:

```yaml
services:
  products-agent:
    env_file:
      - .env  # Base configuration
    environment:
      - ENTRA_CLIENT_SECRET=override_value  # Override specific values
```

### Post-Deployment Checklist

After every `terraform apply`, verify these critical configurations:

1. **✅ Client Secrets Updated**: Check that new client secrets are in docker-compose files
2. **✅ JWT Audience Correct**: Verify JWT audience matches identifier URI or client ID
3. **✅ Nova Pro Configuration**: Ensure inference profile ID is used, not model ID
4. **✅ Multi-Region Permissions**: Verify IAM policy includes all required regions
5. **✅ ECR Region Match**: Confirm ECR login uses correct region
6. **✅ Container Rebuild**: Force rebuild if authentication changes were made
7. **✅ Environment Variables**: Check that environment variables are properly set

### Automated Fix Script

Create a script to automate post-deployment fixes:

```bash
#!/bin/bash
# post-deploy-fix.sh

echo "🔧 Applying post-deployment fixes..."

# Get new client secrets
cd terraform
PRODUCTS_WEB_SECRET=$(terraform output -raw products_web_client_secret)
PRODUCTS_AGENT_SECRET=$(terraform output -raw products_agent_client_secret)
cd ..

# Update docker-compose files
sed -i "s/ENTRA_CLIENT_SECRET=.*/ENTRA_CLIENT_SECRET=$PRODUCTS_AGENT_SECRET/" docker-compose/products-agent/docker-compose.yml
sed -i "s/CLIENT_SECRET=.*/CLIENT_SECRET=$PRODUCTS_WEB_SECRET/" docker-compose/products-web/.env

# Force rebuild and redeploy
./deploy-ecr.sh build
./deploy-ecr.sh deploy

echo "✅ Post-deployment fixes applied!"
```

## Infrastructure Setup

### 1. Clone and Navigate

```bash
git clone <repository-url>
cd terraform
```

### 2. Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file with your specific values
nano terraform.tfvars
```

### 4. Configure Provider Settings

**Important**: You must also update the `providers.tf` file to use your specific HCP organization and project details:

```bash
# Edit the providers configuration file
nano providers.tf
```

**Required Changes in `providers.tf`:**

1. **Update HCP Organization**: Uncomment and set your organization name:
   ```hcl
   data "hcp_organization" "myorg" {
     name = "your-organization-name"  # Replace with your actual HCP org name
   }
   ```

2. **Update HCP Project ID**: Set your specific project ID:
   ```hcl
   data "hcp_project" "myproject" {
     project = "your-project-id"  # Replace with your actual HCP project ID
   }
   ```

**Finding Your HCP Details:**
- **Organization Name**: Found in your HCP dashboard URL or organization settings
- **Project ID**: Found in your HCP project settings or URL

### 5. Configure Region-Specific Variables

**Important**: If you're deploying to a different AWS region than `eu-central-1`, you must update the `variables.tf` file:

```bash
# Edit the variables configuration file
nano variables.tf
```

**Required Changes in `variables.tf` for Different Regions:**

1. **Update AWS Region**: Change the default region:
   ```hcl
   variable "aws_region" {
     description = "AWS region for resources"
     type        = string
     default     = "us-east-1"  # Change from "eu-central-1" to your target region
   }
   ```

2. **Update HCP HVN Region**: Change the HVN region to match:
   ```hcl
   variable "hvn_region" {
     description = "The region where the HVN should be created"
     type        = string
     default     = "us-east-1"  # Change from "eu-central-1" to your target region
   }
   ```

3. **Update Availability Zones**: Change AZs to match your target region:
   ```hcl
   variable "availability_zones" {
     description = "List of availability zones"
     type        = list(string)
     default     = ["us-east-1a", "us-east-1b"]  # Change from eu-central-1 AZs
   }
   ```

**Common AWS Regions and Availability Zones:**
- **us-east-1**: `["us-east-1a", "us-east-1b", "us-east-1c"]`
- **us-west-2**: `["us-west-2a", "us-west-2b", "us-west-2c"]`
- **eu-west-1**: `["eu-west-1a", "eu-west-1b", "eu-west-1c"]`
- **ap-southeast-1**: `["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]`

**Note**: Ensure your target region supports all required AWS services (DocumentDB, EKS, etc.).

**Required Variables to Configure:**

```hcl
# General
resource_prefix = "ai"  # Will be combined with 3-char random suffix
aws_region      = "us-east-1"

# HCP Configuration
hcp_client_id     = "<hcp-client-id>"
hcp_client_secret = "<hcp-client-secret>" 

# DocumentDB Configuration
docdb_master_username    = "docdbadmin"
docdb_master_password    = "ChangeMe123!"  # Change this to a secure password
docdb_instance_class     = "db.t3.medium"
docdb_instance_count     = 1

# Bastion Host Configuration  
bastion_instance_type = "t3.medium"

# JWT Auth Configuration
jwt_oidc_discovery_url = "https://your-oidc-provider.com/.well-known/openid_configuration"
jwt_bound_issuer="https://login.microsoftonline.com/<tenant-id>/v2.0

# AzureAD service principal configuration
azure_client_id="your-azure-service-principal-client-id"
azure_client_secret="your-azure-service-principal-client-secret"
azure_tenant_id="your-azure-tenant-id"
ad_user_password="password-for-test-users!"
```

### 6. Initialize Terraform

```bash
# Initialize Terraform with all required providers
terraform init
```

This will download and configure the following providers:
- `hashicorp/hcp` - For HCP Vault and HVN management
- `hashicorp/aws` - For AWS resource management
- `hashicorp/azuread` - For Azure AD application management
- `hashicorp/azurerm` - For Azure resource management
- `hashicorp/vault` - For Vault configuration
- `hashicorp/tls` - For TLS certificate generation
- `hashicorp/random` - For random resource naming
- `hashicorp/local` - For local file operations

### 7. Plan Deployment

```bash
# Review the planned infrastructure changes
terraform plan
```

This command will show you:
- All resources that will be created
- Dependencies between resources  
- Any potential issues with your configuration

### 8. Deploy Infrastructure

```bash
# Apply the Terraform configuration
terraform apply
```

**Deployment Process:**
1. **Resource Creation Order**: Terraform will create resources in the correct dependency order
2. **Duration**: Full deployment typically takes 15-20 minutes
3. **Monitoring**: Watch the output for any errors or warnings
4. **Confirmation**: Type `yes` when prompted to proceed with deployment

**What Gets Created:**

- **HCP Resources**:
  - HashiCorp Virtual Network (HVN) with CIDR `172.25.16.0/20`
  - Vault Plus cluster with public endpoint access
  - Admin token for initial Vault access

- **AWS Resources**:
  - VPC with CIDR `10.0.0.0/16` (configurable)
  - Public and private subnets across multiple AZs
  - Internet Gateway and NAT Gateways
  - VPC peering connection to HCP HVN
  - DocumentDB cluster with security groups
  - EC2 bastion host with application services
  - Application Load Balancer with SSL certificate
  - Security groups and routing tables

- **Azure AD Resources**:
  - Application registrations for web and API components
  - Service principals with required permissions
  - User groups for role-based access control
  - Test users with appropriate group memberships

- **Vault Configuration**:
  - JWT authentication method configured
  - Database secrets engine for DocumentDB
  - Policies for different access levels
  - Identity groups mapped to Azure AD groups

## Infrastructure Teardown

### Destroy Infrastructure

When you need to tear down the infrastructure:

```bash
# Destroy all Terraform-managed resources
terraform destroy
```

### Selective Resource Management

```bash
# Destroy specific resources
terraform destroy -target=module.bastion

# Recreate specific resources  
terraform apply -target=module.aws_documentdb

# Plan changes for specific resources
terraform plan -target=module.vault_auth
```

## Post-Deployment Configuration

After successful deployment, Terraform will output important connection details and URLs. Use these outputs to access and configure your deployed services.

### Access Information

```bash
# Get all Terraform outputs
terraform output

# Get specific outputs
terraform output vault_public_endpoint_url
terraform output bastion_public_ip
terraform output documentdb_cluster_endpoint
terraform output alb_https_url
```

### Application Deployment

The bastion host comes pre-configured with:
- Docker and Docker Compose for container deployment
- MongoDB tools for database management

### Next Steps

1. **Access Vault**: Use the admin token to review configured policies, AWS DocumentDB secrets engine, JWT authentication method and identity groups
2. **Database Setup**: Connect to DocumentDB and review the collection (produts) and sample documents
3. **Application Deployment**: Deploy your agentic applications to the bastion host using ../docker-compose


## Module Structure

```
terraform/
├── main.tf                    # Main infrastructure orchestration
├── variables.tf              # Input variable definitions  
├── outputs.tf               # Output value definitions
├── providers.tf             # Provider configurations
├── terraform.tfvars.example # Example configuration file
└── modules/
    ├── hcp-vault/           # HCP HVN and Vault cluster
    ├── aws-networking/      # VPC, subnets, and connectivity
    ├── aws-documentdb/      # DocumentDB cluster and security
    ├── bastion/            # EC2 bastion with application services
    ├── azure-ad-app/       # Azure AD applications and users
    └── vault-auth/         # Vault authentication configuration
```

## Network Configuration

### CIDR Blocks (Non-Overlapping)
- **HCP HVN**: `172.25.16.0/20` (172.25.16.1 - 172.25.31.254)
- **AWS VPC**: `10.0.0.0/16` (10.0.0.1 - 10.0.255.254)
- **Public Subnets**: `10.0.1.0/24`, `10.0.2.0/24`
- **Private Subnets**: `10.0.10.0/24`, `10.0.20.0/24`

### Security Groups
- **DocumentDB**: Allows MongoDB port 27017 from VPC and HVN CIDR blocks
- **Bastion**: Allows SSH (22) and HTTPS (443) with controlled access
- **Application Load Balancer**: Allows HTTP (80) and HTTPS (443) from internet

---

**⚠️ Important**: This infrastructure creates billable resources in HCP, AWS, and Azure. Monitor costs and destroy resources when not needed for development/testing purposes.
