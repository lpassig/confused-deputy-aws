WEBAPP_CLIENT_ID=7145iqso344a5sr8v98enhiltl
WEBAPP_CLIENT_SECRET=14dg841rofnvkegjh4b2df4f9coug94k683rga2gd81rcjmjesjn

AGENT_CLIENT_ID=7oiocadqrrqdpektc5lnl6davo
AGENT_CLIENT_SECRET=1ol6idpk1n60mnvs0pjt3l6m4i3amguuh6cjse72g6n2qahtro59
AGENT_SCOPE_READ=strands_agent_demo/agent.invoke

PRODUCTS_MCP_SCOPES="products-mcp/products.create products-mcp/products.list products-mcp/products.read products-mcp/products.update"

COGNITO_DOMAIN=https://us-east-1odunf1ust.auth.us-east-1.amazoncognito.com

## 1. Get Auth Code (OIDC)
## Use a browswer to initiate OIDC login
echo "$COGNITO_DOMAIN/oauth2/authorize?client_id=$WEBAPP_CLIENT_ID&response_type=code&redirect_uri=https://localhost:3000/auth/callback&response_mode=query&scope=openid profile email $AGENT_SCOPE_READ&state=12345" | pbcopy

### After login, capture the code from the redirect URI
export AUTH_CODE=b5f6b9b8-0f7c-43a1-b803-ce7fef0e674e

## 2. Exchange Auth Code for Tokens (Web App)
export TOKENS=$(curl -s -X POST $COGNITO_DOMAIN/oauth2/token -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=${WEBAPP_CLIENT_ID}" -d "scope=${AGENT_SCOPE_READ} openid profile email" -d "code=${AUTH_CODE}" -d "redirect_uri=https://localhost:3000/auth/callback" -d "grant_type=authorization_code" -d "client_secret=${WEBAPP_CLIENT_SECRET}")

### This will return "access_token" and "id_token"
access_token=$(echo $TOKENS | jq .access_token -r)
jwt decode $access_token

###  3. OBO Token Exchange (Middle Tier)
### Use the access_token received above in assertion field:

export OBO_TOKENS=$(curl -s -X POST $COGNITO_DOMAIN/oauth2/token -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$AGENT_CLIENT_ID" -d "client_secret=$AGENT_CLIENT_SECRET" -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" -d "requested_token_use=on_behalf_of" -d "scope=openid profile email $PRODUCTS_MCP_SCOPES" -d "assertion=$access_token")

obo_access_token=$(echo $OBO_TOKENS | jq .access_token -r)
jwt decode $obo_access_token