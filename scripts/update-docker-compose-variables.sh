#!/bin/bash

# Update Docker Compose files with variables
# This script replaces hardcoded values in docker-compose files with environment variables

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Function to update docker-compose file
update_docker_compose_file() {
    local file_path=$1
    local service_name=$2
    
    if [ ! -f "$file_path" ]; then
        warn "Docker compose file not found: $file_path"
        return 1
    fi
    
    log "Updating $file_path..."
    
    # Create backup
    cp "$file_path" "$file_path.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Replace hardcoded values with variables
    sed -i.tmp \
        -e "s|ENTRA_CLIENT_ID=$PRODUCTS_AGENT_CLIENT_ID|ENTRA_CLIENT_ID=\${ENTRA_CLIENT_ID}|g" \
        -e "s|ENTRA_CLIENT_ID=$PRODUCTS_WEB_CLIENT_ID|ENTRA_CLIENT_ID=\${ENTRA_CLIENT_ID}|g" \
        -e "s|ENTRA_CLIENT_SECRET=.*|ENTRA_CLIENT_SECRET=\${ENTRA_CLIENT_SECRET}|g" \
        -e "s|CLIENT_SECRET=.*|CLIENT_SECRET=\${CLIENT_SECRET}|g" \
        -e "s|https://login.microsoftonline.com/$TENANT_ID|https://login.microsoftonline.com/\${TENANT_ID}|g" \
        -e "s|https://sts.windows.net/$TENANT_ID|https://sts.windows.net/\${TENANT_ID}|g" \
        -e "s|JWT_AUDIENCE=$PRODUCTS_AGENT_CLIENT_ID|JWT_AUDIENCE=\${JWT_AUDIENCE}|g" \
        -e "s|JWT_AUDIENCE=$PRODUCTS_WEB_CLIENT_ID|JWT_AUDIENCE=\${JWT_AUDIENCE}|g" \
        -e "s|JWT_AUDIENCE=$PRODUCTS_MCP_CLIENT_ID|JWT_AUDIENCE=\${JWT_AUDIENCE}|g" \
        "$file_path"
    
    # Remove temporary file
    rm -f "$file_path.tmp"
    
    log "✅ Updated $file_path"
}

log "🔧 Updating Docker Compose files with variables..."

# Update products-agent docker-compose.yml
update_docker_compose_file "docker-compose/products-agent/docker-compose.yml" "products-agent"

# Update products-web docker-compose.yml
update_docker_compose_file "docker-compose/products-web/docker-compose.yml" "products-web"

# Update products-mcp docker-compose.yml
update_docker_compose_file "docker-compose/products-mcp/docker-compose.yml" "products-mcp"

# Update unified docker-compose file
update_docker_compose_file "docker-compose-unified.yml" "unified"

log "🎉 All Docker Compose files updated with variables!"
log "💡 Remember to update your .env files with the actual values"
