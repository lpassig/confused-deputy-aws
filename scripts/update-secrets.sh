#!/bin/bash

# Ultimate automated secret updater
# This script handles both .env files and hardcoded docker-compose.yml values

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Function to get current secret from Terraform output
get_current_secret() {
    local app_name=$1
    cd "$TERRAFORM_DIR"
    terraform output -raw "${app_name}_client_secret" 2>/dev/null || echo ""
}

# Function to get current secret from container environment
get_container_secret() {
    local container_name=$1
    local env_var=$2
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
        "docker exec $container_name env | grep '^$env_var=' | cut -d'=' -f2-" 2>/dev/null || echo ""
}

# Function to update all secret locations
update_all_secret_locations() {
    local container_name=$1
    local env_file_path=$2
    local env_var=$3
    local current_secret=$4
    
    info "Updating all secret locations for $container_name..."
    
    # Update .env file
    log "Updating $env_file_path..."
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
        "sed -i 's/$env_var=.*/$env_var=$current_secret/' $env_file_path"
    
    # Update docker-compose.yml if it has hardcoded values
    local compose_file="$DOCKER_COMPOSE_DIR/$container_name/docker-compose.yml"
    log "Checking for hardcoded secrets in $compose_file..."
    
    local has_hardcoded=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
        "grep -q '$env_var=' $compose_file && echo 'yes' || echo 'no'")
    
    if [ "$has_hardcoded" = "yes" ]; then
        warn "Found hardcoded $env_var in docker-compose.yml - updating..."
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
            "sed -i 's/$env_var=.*/$env_var=$current_secret/' $compose_file"
        log "Updated hardcoded secret in docker-compose.yml"
    else
        info "No hardcoded $env_var found in docker-compose.yml"
    fi
}

# Function to completely recreate container with new secret
recreate_container_with_secret() {
    local container_name=$1
    local env_file_path=$2
    local env_var=$3
    local app_name=$4
    
    log "Checking $container_name for $app_name secret updates..."
    
    # Get current secrets
    local current_secret=$(get_current_secret "$app_name")
    local container_secret=$(get_container_secret "$container_name" "$env_var")
    
    if [ -z "$current_secret" ]; then
        error "Could not get current secret for $app_name from Terraform"
        return 1
    fi
    
    if [ "$current_secret" != "$container_secret" ]; then
        warn "Secret mismatch detected for $app_name:"
        warn "  Container: ${container_secret:0:10}..."
        warn "  Terraform:  ${current_secret:0:10}..."
        
        # Update all secret locations
        update_all_secret_locations "$container_name" "$env_file_path" "$env_var" "$current_secret"
        
        # Completely stop and remove container
        log "Stopping and removing $container_name..."
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
            "docker stop $container_name || true && docker rm $container_name || true"
        
        # Wait a moment for cleanup
        sleep 2
        
        # Recreate container using docker-compose
        log "Recreating $container_name with new secret..."
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
            "cd $DOCKER_COMPOSE_DIR && docker compose up -d $container_name"
        
        # Wait for container to be healthy
        log "Waiting for $container_name to be healthy..."
        local max_attempts=30
        local attempt=0
        
        while [ $attempt -lt $max_attempts ]; do
            local status=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
                "docker ps --format '{{.Status}}' --filter name=$container_name" 2>/dev/null || echo "")
            
            if echo "$status" | grep -q "healthy\|Up"; then
                log "$container_name is now healthy"
                break
            fi
            sleep 2
            attempt=$((attempt + 1))
        done
        
        if [ $attempt -eq $max_attempts ]; then
            error "$container_name failed to become healthy after $max_attempts attempts"
            return 1
        fi
        
        # Verify the secret was actually updated
        local new_container_secret=$(get_container_secret "$container_name" "$env_var")
        if [ "$new_container_secret" = "$current_secret" ]; then
            log "✅ Successfully updated $container_name with new secret"
        else
            error "❌ Secret update failed - container still has old secret"
            return 1
        fi
    else
        log "$container_name secret is up to date"
    fi
}

# Function to check authentication health
check_auth_health() {
    local container_name=$1
    local health_endpoint=$2
    
    log "Checking authentication health for $container_name..."
    
    # Try to make a request that would trigger authentication
    local response=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
        "curl -s -o /dev/null -w '%{http_code}' $health_endpoint" 2>/dev/null || echo "000")
    
    if [ "$response" = "200" ] || [ "$response" = "401" ]; then
        log "$container_name authentication is working (HTTP $response)"
        return 0
    else
        warn "$container_name authentication may have issues (HTTP $response)"
        return 1
    fi
}

# Main execution
main() {
    log "🚀 Starting ULTIMATE automatic secret update process..."
    
    # Update ProductsAgent with complete recreation
    recreate_container_with_secret "$PRODUCTS_AGENT_CONTAINER" \
        "$DOCKER_COMPOSE_DIR/products-agent/.env" \
        "$AGENT_SECRET_ENV_VAR" \
        "products_agent"
    
    # Update ProductsWeb with complete recreation
    recreate_container_with_secret "$PRODUCTS_WEB_CONTAINER" \
        "$DOCKER_COMPOSE_DIR/products-web/.env" \
        "$WEB_SECRET_ENV_VAR" \
        "products_web"
    
    # Wait a bit for services to stabilize
    sleep 10
    
    # Check authentication health
    check_auth_health "$PRODUCTS_AGENT_CONTAINER" "http://localhost:$PRODUCTS_AGENT_PORT$PRODUCTS_AGENT_HEALTH"
    check_auth_health "$PRODUCTS_WEB_CONTAINER" "http://localhost:$PRODUCTS_WEB_PORT$PRODUCTS_WEB_HEALTH"
    
    log "🎉 ULTIMATE automatic secret update process completed successfully!"
}

# Run main function
main "$@"
