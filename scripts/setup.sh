#!/bin/bash

# Setup script for automated secret management
# This script helps users set up the configuration for their environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
TEMPLATE_FILE="$SCRIPT_DIR/config.sh.template"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log "🔧 Setting up automated secret management configuration..."

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
    warn "Configuration file already exists: $CONFIG_FILE"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Setup cancelled. Existing configuration preserved."
        exit 0
    fi
fi

# Copy template to config
if [ -f "$TEMPLATE_FILE" ]; then
    cp "$TEMPLATE_FILE" "$CONFIG_FILE"
    log "Created configuration file from template"
else
    error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Make config file executable
chmod +x "$CONFIG_FILE"

log "📝 Configuration file created: $CONFIG_FILE"
log ""
log "🔧 Next steps:"
log "1. Edit the configuration file with your values:"
log "   nano $CONFIG_FILE"
log ""
log "2. Or run auto-configure to populate from Terraform:"
log "   ./scripts/auto-configure.sh"
log ""
log "3. Then run the secret management scripts:"
log "   ./scripts/update-secrets.sh"
log ""
log "💡 Key values to update:"
log "   - BASTION_HOST: Your bastion host IP"
log "   - SSH_KEY: Path to your SSH private key"
log "   - TENANT_ID: Your Microsoft Entra ID tenant ID"
log "   - PRODUCTS_AGENT_CLIENT_ID: ProductsAgent app registration ID"
log "   - PRODUCTS_WEB_CLIENT_ID: ProductsWeb app registration ID"
log "   - PRODUCTS_MCP_CLIENT_ID: ProductsMCP app registration ID"
log ""
log "✅ Setup completed!"
