#!/bin/bash
export TF_STATE=/Users/ravipanchal/learn/vault/confused-deputy-aws/terraform/terraform.tfstate

cat > ./products-web/.env <<EOF
TENANT_ID=0aa96723-98b3-4842-9673-73bafaafde70
CLIENT_ID=$(terraform output -state=$TF_STATE -raw products_web_client_id)
CLIENT_SECRET=$(terraform output -state=$TF_STATE -raw products_web_client_secret)
SCOPE="openid profile email $(terraform output -state=$TF_STATE -json products_agent_scopes | jq '. | join(" ")' -r)"
REDIRECT_URI=$(terraform output -state=$TF_STATE -raw alb_https_url)/oauth2callback
BASE_URL=https://login.microsoftonline.com
PRODUCTS_API_BASE_URL=http://products-agent:8001
EOF

cat > ./products-agent/.env <<EOF
JWKS_URI=https://login.windows.net/common/discovery/keys
JWT_ISSUER=https://login.microsoftonline.com/0aa96723-98b3-4842-9673-73bafaafde70/v2.0
JWT_AUDIENCE=$(terraform output -state=$TF_STATE -raw products_agent_client_id)
ENTRA_TENANT_ID=0aa96723-98b3-4842-9673-73bafaafde70

# Microsoft Entra ID OAuth On-Behalf-Of Flow Configuration
ENTRA_CLIENT_ID=$(terraform output -state=$TF_STATE -raw products_agent_client_id)
ENTRA_CLIENT_SECRET=$(terraform output -state=$TF_STATE -raw products_agent_client_secret)
ENTRA_SCOPE="$(terraform output -state=$TF_STATE -json products_mcp_scopes | jq '. | join(" ")' -r)"
ENTRA_TOKEN_URL=https://login.microsoftonline.com/0aa96723-98b3-4842-9673-73bafaafde70/oauth2/v2.0/token

# MCP Server Configuration
PRODUCTS_MCP_SERVER_URL=http://products-mcp:8000/mcp
EOF

cat > ./products-mcp/.env <<EOF
# AWS DocumentDB Configuration
DB_HOST=$(terraform output -state=$TF_STATE -raw documentdb_cluster_endpoint)
DB_PORT=$(terraform output -state=$TF_STATE -raw documentdb_cluster_port)
DB_NAME=test
DB_USERNAME=username
DB_PASSWORD=password
COLLECTION_NAME=products

# SSL Configuration (recommended for AWS DocumentDB)
USE_SSL=false
SSL_CA_CERT_PATH=/path/to/rds-ca-2019-root.pem

# MCP Server Configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
SERVER_NAME=products-mcp
SERVER_VERSION=1.0.0

# Logging Configuration
LOG_LEVEL=INFO
LOG_FILE=

# Application Settings
DEBUG=false
MAX_RESULTS=100

JWKS_URI=https://login.windows.net/common/discovery/keys
JWT_ISSUER=https://login.microsoftonline.com/0aa96723-98b3-4842-9673-73bafaafde70/v2.0
JWT_AUDIENCE=$(terraform output -state=$TF_STATE -raw products_mcp_client_id)
ENTRA_TENANT_ID=0aa96723-98b3-4842-9673-73bafaafde70
VAULT_ADDR=$(terraform output -state=$TF_STATE -raw vault_private_endpoint_url)
EOF