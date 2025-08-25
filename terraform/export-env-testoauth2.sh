#!/bin/bash
cat > ./test_oauth2_flow/setup_env.sh <<EOF
export TENANT_ID=0aa96723-98b3-4842-9673-73bafaafde70
export WEBAPP_CLIENT_ID=$(terraform output -raw products_web_client_id)
export WEBAPP_CLIENT_SECRET=$(terraform output -raw products_web_client_secret)
export WEBAPP_CLIENT_SCOPES="openid profile email $(terraform output -json products_agent_scopes | jq '. | join(" ")' -r)"
export WEBAPP_REDIRECT_URI=http://localhost:8501/oauth2callback

export PRODUCTS_AGENT_CLIENT_ID=$(terraform output -raw products_agent_client_id)
export PRODUCTS_AGENT_CLIENT_SECRET=$(terraform output -raw products_agent_client_secret)
export PRODUCTS_AGENT_SCOPES="$(terraform output -json products_mcp_scopes | jq '. | join(" ")' -r)"
EOF