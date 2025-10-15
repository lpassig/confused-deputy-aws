#!/bin/bash

# Auto-configure script
# This script automatically populates the config.sh file with values from Terraform outputs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")/terraform"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Check if Terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    error "Terraform directory not found at $TERRAFORM_DIR"
    exit 1
fi

# Check if terraform is initialized
if [ ! -f "$TERRAFORM_DIR/.terraform/terraform.tfstate" ] && [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    warn "Terraform not initialized. Run 'terraform init' first."
    exit 1
fi

log "🔧 Auto-configuring scripts with Terraform outputs..."

# Get Terraform outputs
cd "$TERRAFORM_DIR"

# Get bastion host IP
BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
if [ -z "$BASTION_IP" ]; then
    warn "Could not get bastion_public_ip from Terraform output"
    BASTION_IP="YOUR_BASTION_HOST_IP"  # fallback
fi

# Get Azure AD configuration
TENANT_ID=$(terraform output -raw tenant_id 2>/dev/null || echo "")
if [ -z "$TENANT_ID" ]; then
    warn "Could not get tenant_id from Terraform output"
    TENANT_ID="YOUR_TENANT_ID"  # fallback
fi

PRODUCTS_AGENT_CLIENT_ID=$(terraform output -raw products_agent_client_id 2>/dev/null || echo "")
if [ -z "$PRODUCTS_AGENT_CLIENT_ID" ]; then
    warn "Could not get products_agent_client_id from Terraform output"
    PRODUCTS_AGENT_CLIENT_ID="YOUR_PRODUCTS_AGENT_CLIENT_ID"  # fallback
fi

PRODUCTS_WEB_CLIENT_ID=$(terraform output -raw products_web_client_id 2>/dev/null || echo "")
if [ -z "$PRODUCTS_WEB_CLIENT_ID" ]; then
    warn "Could not get products_web_client_id from Terraform output"
    PRODUCTS_WEB_CLIENT_ID="YOUR_PRODUCTS_WEB_CLIENT_ID"  # fallback
fi

PRODUCTS_MCP_CLIENT_ID=$(terraform output -raw products_mcp_client_id 2>/dev/null || echo "")
if [ -z "$PRODUCTS_MCP_CLIENT_ID" ]; then
    warn "Could not get products_mcp_client_id from Terraform output"
    PRODUCTS_MCP_CLIENT_ID="YOUR_PRODUCTS_MCP_CLIENT_ID"  # fallback
fi

# Get SSH key path
SSH_KEY_PATH="terraform/YOUR_SSH_KEY.pem"
if [ ! -f "$(dirname "$TERRAFORM_DIR")/$SSH_KEY_PATH" ]; then
    warn "SSH key not found at $SSH_KEY_PATH"
    SSH_KEY_PATH="terraform/YOUR_SSH_KEY.pem"  # fallback
fi

log "📝 Updating configuration file..."

# Create backup of existing config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    log "Created backup of existing config file"
fi

# Generate new config file with environment variable fallbacks
cat > "$CONFIG_FILE" << EOF
#!/bin/bash

# Configuration file for automated secret management scripts
# This file contains all the hardcoded values that need to be updated for different environments
# Generated automatically by auto-configure.sh on $(date)

# =============================================================================
# BASTION HOST CONFIGURATION
# =============================================================================
# Updated from Terraform output: bastion_public_ip
BASTION_HOST="\${BASTION_HOST:-$BASTION_IP}"
SSH_KEY="\${SSH_KEY:-$SSH_KEY_PATH}"

# =============================================================================
# MICROSOFT ENTRA ID CONFIGURATION
# =============================================================================
# Updated from Terraform outputs
TENANT_ID="\${TENANT_ID:-$TENANT_ID}"
PRODUCTS_AGENT_CLIENT_ID="\${PRODUCTS_AGENT_CLIENT_ID:-$PRODUCTS_AGENT_CLIENT_ID}"
PRODUCTS_WEB_CLIENT_ID="\${PRODUCTS_WEB_CLIENT_ID:-$PRODUCTS_WEB_CLIENT_ID}"
PRODUCTS_MCP_CLIENT_ID="\${PRODUCTS_MCP_CLIENT_ID:-$PRODUCTS_MCP_CLIENT_ID}"

# =============================================================================
# DERIVED CONFIGURATION (DO NOT MODIFY)
# =============================================================================
# These values are automatically derived from the above configuration
JWKS_URI="https://login.microsoftonline.com/\${TENANT_ID}/discovery/v2.0/keys"
JWT_ISSUER="https://login.microsoftonline.com/\${TENANT_ID}/v2.0"
ENTRA_TOKEN_URL="https://login.microsoftonline.com/\${TENANT_ID}/oauth2/v2.0/token"

# =============================================================================
# SERVICE CONFIGURATION
# =============================================================================
# Service names and ports (usually don't need to change)
PRODUCTS_AGENT_CONTAINER="products-agent"
PRODUCTS_WEB_CONTAINER="products-web"
PRODUCTS_MCP_CONTAINER="products-mcp"

PRODUCTS_AGENT_PORT="8001"
PRODUCTS_WEB_PORT="8501"
PRODUCTS_MCP_PORT="8000"

# Health check endpoints
PRODUCTS_AGENT_HEALTH="/health"
PRODUCTS_WEB_HEALTH="/_stcore/health"
PRODUCTS_MCP_HEALTH="/mcp"

# =============================================================================
# ENVIRONMENT VARIABLE NAMES
# =============================================================================
# These are the environment variable names used in containers
AGENT_SECRET_ENV_VAR="ENTRA_CLIENT_SECRET"
WEB_SECRET_ENV_VAR="CLIENT_SECRET"

# =============================================================================
# TERRAFORM OUTPUT NAMES
# =============================================================================
# These are the Terraform output names for client secrets
AGENT_SECRET_OUTPUT="products_agent_client_secret"
WEB_SECRET_OUTPUT="products_web_client_secret"

# =============================================================================
# LOG PATTERNS FOR MONITORING
# =============================================================================
# Patterns to look for in logs to detect authentication failures
AUTH_ERROR_PATTERNS="invalid_client|AADSTS7000215|Token exchange failed|Authentication failed"

# =============================================================================
# PATHS
# =============================================================================
# Directory paths (update if your structure is different)
TERRAFORM_DIR="terraform"
DOCKER_COMPOSE_DIR="/home/ubuntu/docker-compose"
LOG_FILE="/home/ubuntu/auto-update-secrets.log"

# =============================================================================
# USAGE INSTRUCTIONS
# =============================================================================
# To use this configuration file in your scripts:
# 1. Source this file: source scripts/config.sh
# 2. Use the variables: echo "Bastion: \$BASTION_HOST"
# 3. Update values above for your environment
# 4. Run scripts as normal: ./scripts/update-secrets.sh
EOF

log "✅ Configuration file updated successfully!"
log "📋 Summary of configured values:"
log "   Bastion Host: $BASTION_IP"
log "   Tenant ID: $TENANT_ID"
log "   ProductsAgent Client ID: $PRODUCTS_AGENT_CLIENT_ID"
log "   ProductsWeb Client ID: $PRODUCTS_WEB_CLIENT_ID"
log "   ProductsMCP Client ID: $PRODUCTS_MCP_CLIENT_ID"
log "   SSH Key: $SSH_KEY_PATH"

log "🎉 Auto-configuration completed!"
log "💡 You can now run: ./scripts/update-secrets.sh"
