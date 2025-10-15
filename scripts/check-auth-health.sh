#!/bin/bash

# Simple authentication health monitor
# This script checks for authentication failures and triggers updates if needed

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

UPDATE_SCRIPT="scripts/update-secrets.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to check for authentication failures in logs
check_auth_failures() {
    local container_name=$1
    local log_pattern=$2
    
    log "Checking $container_name for authentication failures..."
    
    # Check recent logs for authentication failures
    local auth_errors=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
        "docker logs $container_name --since=5m 2>&1 | grep -c \"$log_pattern\" 2>/dev/null || echo \"0\"")
    
    if [ "$auth_errors" -gt 0 ]; then
        warn "Authentication failures detected in $container_name: $auth_errors errors in last 5 minutes"
        return 0
    else
        log "$container_name: No authentication failures detected"
        return 1
    fi
}

# Function to check HTTP health
check_http_health() {
    local service_name=$1
    local url=$2
    local expected_codes=$3
    
    log "Checking HTTP health for $service_name..."
    
    local response=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$BASTION_HOST" \
        "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 $url" 2>/dev/null || echo "000")
    
    # Check if response code is in expected range
    for code in $expected_codes; do
        if [ "$response" = "$code" ]; then
            log "$service_name HTTP health check passed (HTTP $response)"
            return 0
        fi
    done
    
    warn "$service_name HTTP health check failed: got $response, expected one of: $expected_codes"
    return 1
}

# Main monitoring function
main() {
    log "Starting authentication health check..."
    
    local needs_update=false
    
    # Check ProductsAgent
    if check_auth_failures "products-agent" "invalid_client\|AADSTS7000215\|Token exchange failed"; then
        needs_update=true
    fi
    
    # Check ProductsWeb
    if check_auth_failures "products-web" "invalid_client\|AADSTS7000215\|Authentication failed"; then
        needs_update=true
    fi
    
    # Check HTTP health
    if ! check_http_health "ProductsAgent" "http://localhost:8001/health" "200"; then
        needs_update=true
    fi
    
    if ! check_http_health "ProductsWeb" "http://localhost:8501/_stcore/health" "200"; then
        needs_update=true
    fi
    
    # Trigger update if needed
    if [ "$needs_update" = true ]; then
        warn "Authentication issues detected. Triggering automatic secret update..."
        if [ -f "$UPDATE_SCRIPT" ]; then
            chmod +x "$UPDATE_SCRIPT"
            "$UPDATE_SCRIPT"
            log "Secret update completed"
        else
            error "Update script not found at $UPDATE_SCRIPT"
            exit 1
        fi
    else
        log "All services healthy, no update needed"
    fi
    
    log "Authentication health check completed"
}

# Run main function
main "$@"
