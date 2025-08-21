#!/bin/bash

# OAuth2 Flow Test - Environment Setup Script
# Copy this file to setup_env.sh and customize the values

echo "Setting up environment variables for OAuth2 flow test..."

# Azure AD Tenant ID
export TENANT_ID="0aa96723-98b3-4842-9673-73bafaafde70"

# Web App (Frontend) Configuration
export WEBAPP_CLIENT_ID="your-webapp-client-id-here"
export WEBAPP_CLIENT_SECRET="your-webapp-client-secret-here"
export WEBAPP_CLIENT_SCOPES="openid profile email your-custom-scopes"

# Products Agent (Middle Tier) Configuration
export PRODUCTS_AGENT_CLIENT_ID="your-products-agent-client-id-here"
export PRODUCTS_AGENT_CLIENT_SECRET="your-products-agent-client-secret-here"
export PRODUCTS_AGENT_SCOPES="your-agent-scopes-here"

echo "✅ Environment variables set!"
echo "📝 Please update the values in this script before running"
echo ""
echo "To use:"
echo "1. Edit this file with your actual values"
echo "2. Run: source setup_env_template.sh"
echo "3. Run: python test_oauth2_flow.py"