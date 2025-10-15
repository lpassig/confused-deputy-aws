#!/bin/bash

# Terraform post-apply hook
# This script runs automatically after terraform apply to update secrets

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update-secrets.sh"

echo "🔧 Terraform apply completed. Running automatic secret update..."

if [ -f "$UPDATE_SCRIPT" ]; then
    # Make script executable
    chmod +x "$UPDATE_SCRIPT"
    
    # Run the update script
    "$UPDATE_SCRIPT"
    
    echo "✅ Automatic secret update completed"
else
    echo "❌ Update script not found at $UPDATE_SCRIPT"
    exit 1
fi