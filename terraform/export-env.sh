#!/bin/bash

# This script generates .env files for local or docker development environments.
# It accepts one argument: 'local' or 'docker'.

# --- Argument Validation ---
if [ -z "$1" ]; then
    echo "Usage: $0 [local|docker|aws]"
    echo "  local:  Configure services to run on localhost."
    echo "  docker: Configure services to run in Docker containers."
    echo "  aws: Configure services to run in Docker containers in AWS."
    exit 1
fi

ENV_TYPE=$1

if [ "$ENV_TYPE" != "local" ] && [ "$ENV_TYPE" != "docker" ] && [ "$ENV_TYPE" != "aws" ]; then
    echo "Error: Invalid argument. Please use 'local', 'docker', or 'aws'."
    exit 1
fi

echo "Generating .env files for '$ENV_TYPE' environment..."


# --- Environment-specific Variables ---
if [ "$ENV_TYPE" = "local" ]; then
    ROOT_PATH="/Users/ravipanchal/learn/vault/confused-deputy-aws"
    PRODUCTS_AGENT_URL="http://localhost:8001"
    PRODUCTS_MCP_SERVER_URL="http://localhost:8000/mcp"
    DB_HOST="localhost"
    REDIRECT_URI=http://localhost:8501/oauth2callback
    VAULT_ADDR=$(terraform output -state=$TF_STATE -raw vault_public_endpoint_url)
    ENV_FILE_NAME=".env"
elif [ "$ENV_TYPE" = "aws" ]; then
    ROOT_PATH="/Users/ravipanchal/learn/vault/confused-deputy-aws/docker-compose"
    PRODUCTS_AGENT_URL="http://products-agent:8001"
    PRODUCTS_MCP_SERVER_URL="http://products-mcp:8000/mcp"
    DB_HOST=$(terraform output -state=$TF_STATE -raw documentdb_cluster_endpoint)
    REDIRECT_URI=$(terraform output -state=$TF_STATE -raw alb_https_url)/oauth2callback
    VAULT_ADDR=$(terraform output -state=$TF_STATE -raw vault_private_endpoint_url)
    ENV_FILE_NAME=".env"
else # docker
    ROOT_PATH="/Users/ravipanchal/learn/vault/confused-deputy-aws/docker-compose"
    PRODUCTS_AGENT_URL="http://products-agent:8001"
    PRODUCTS_MCP_SERVER_URL="http://products-mcp:8000/mcp"
    DB_HOST="$(ipconfig getifaddr en0)"
    REDIRECT_URI=http://localhost:8501/oauth2callback
    VAULT_ADDR=$(terraform output -state=$TF_STATE -raw vault_public_endpoint_url)
    ENV_FILE_NAME=".env.local"
fi

export TF_STATE=/Users/ravipanchal/learn/vault/confused-deputy-aws/terraform/terraform.tfstate

cat > $ROOT_PATH/products-web/$ENV_FILE_NAME <<EOF
TENANT_ID=0aa96723-98b3-4842-9673-73bafaafde70
CLIENT_ID=$(terraform output -state=$TF_STATE -raw products_web_client_id)
CLIENT_SECRET=$(terraform output -state=$TF_STATE -raw products_web_client_secret)
SCOPE="openid profile email $(terraform output -state=$TF_STATE -json products_agent_scopes | jq '. | join(" ")' -r)"
REDIRECT_URI=${REDIRECT_URI}
BASE_URL=https://login.microsoftonline.com
PRODUCTS_AGENT_URL=${PRODUCTS_AGENT_URL}
EOF

cat > $ROOT_PATH/products-agent/$ENV_FILE_NAME <<EOF
JWKS_URI=https://login.windows.net/common/discovery/keys
JWT_ISSUER=https://login.microsoftonline.com/0aa96723-98b3-4842-9673-73bafaafde70/v2.0
JWT_AUDIENCE=$(terraform output -state=$TF_STATE -raw products_agent_client_id)

# Microsoft Entra ID OAuth On-Behalf-Of Flow Configuration
ENTRA_CLIENT_ID=$(terraform output -state=$TF_STATE -raw products_agent_client_id)
ENTRA_CLIENT_SECRET=$(terraform output -state=$TF_STATE -raw products_agent_client_secret)
ENTRA_SCOPE="$(terraform output -state=$TF_STATE -json products_mcp_scopes | jq '. | join(" ")' -r)"
ENTRA_TOKEN_URL=https://login.microsoftonline.com/0aa96723-98b3-4842-9673-73bafaafde70/oauth2/v2.0/token

# Bedrock LLM configuration
BEDROCK_MODEL_ID=amazon.nova-pro-v1:0
BEDROCK_REGION=us-east-1

# MCP Server Configuration
PRODUCTS_MCP_SERVER_URL=${PRODUCTS_MCP_SERVER_URL}
EOF

cat > $ROOT_PATH/products-mcp/$ENV_FILE_NAME <<EOF
# AWS DocumentDB Configuration
DB_HOST=${DB_HOST}
DB_PORT=27017
DB_NAME=test
COLLECTION_NAME=products

# MCP Server Configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
SERVER_NAME=products-mcp

# Application Settings
MAX_RESULTS=100

JWKS_URI=https://login.windows.net/common/discovery/keys
JWT_ISSUER=https://login.microsoftonline.com/0aa96723-98b3-4842-9673-73bafaafde70/v2.0
JWT_AUDIENCE=$(terraform output -state=$TF_STATE -raw products_mcp_client_id)
VAULT_ADDR=${VAULT_ADDR}
EOF
# cp $WORKDIR/products-mcp/.env $WORKDIR/docker-compose/products-mcp/.env.local

if [ "$ENV_TYPE" = "docker" ]; then
    AWS_CREDS_FILE="$HOME/.aws/credentials"
    AGENT_ENV_FILE="$ROOT_PATH/products-agent/.env.local"
    if [ -f "$AWS_CREDS_FILE" ]; then
        ACCESS_KEY=$(awk '/\[default\]/{f=1;next}/\[/{f=0}f && $1=="aws_access_key_id"{print $3}' "$AWS_CREDS_FILE")
        SECRET_KEY=$(awk '/\[default\]/{f=1;next}/\[/{f=0}f && $1=="aws_secret_access_key"{print $3}' "$AWS_CREDS_FILE")
        SESSION_TOKEN=$(awk '/\[default\]/{f=1;next}/\[/{f=0}f && $1=="aws_session_token"{print $3}' "$AWS_CREDS_FILE")
        {
            echo "AWS_ACCESS_KEY_ID=$ACCESS_KEY"
            echo "AWS_SECRET_ACCESS_KEY=$SECRET_KEY"
            if [ -n "$SESSION_TOKEN" ]; then
                echo "AWS_SESSION_TOKEN=$SESSION_TOKEN"
            fi
        } >> "$AGENT_ENV_FILE"
        echo "Appended AWS credentials to $AGENT_ENV_FILE."
    else
        echo "Warning: $AWS_CREDS_FILE not found. AWS credentials not added to $AGENT_ENV_FILE."
    fi
fi

echo "Successfully generated $ENV_FILE_NAME files in $ROOT_PATH."