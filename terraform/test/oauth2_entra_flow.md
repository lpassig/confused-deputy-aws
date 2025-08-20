TENANT_ID=0aa96723-98b3-4842-9673-73bafaafde70
WEBAPP_CLIENT_ID=$(terraform output -raw products_web_client_id)
WEBAPP_CLIENT_SECRET=$(terraform output -raw products_web_client_secret)
WEBAPP_CLIENT_SCOPES="openid profile email $(tfo -json products_agent_scopes | jq '. | join(" ")' -r)"
WEBAPP_REDIRECT_URI=http://localhost:8501/oauth2callback

PRODUCTS_AGENT_CLIENT_ID=$(terraform output -raw products_agent_client_id)
PRODUCTS_AGENT_CLIENT_SECRET=$(terraform output -raw products_agent_client_secret)
PRODUCTS_AGENT_SCOPES="$(tfo -json products_mcp_scopes | jq '. | join(" ")' -r)"

PRODUCTS_MCP_CLIENT_ID=$(terraform output -raw products_mcp_client_id)
<!-- PRODUCTS_MCP_SCOPES=api://$PRODUCTS_MCP_CLIENT_ID/Payments.Access -->

## 1. Get Auth Code (OIDC)
## Use a browswer to initiate OIDC login
echo "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/authorize?client_id=$WEBAPP_CLIENT_ID&response_type=code&redirect_uri=$WEBAPP_REDIRECT_URI&response_mode=query&scope=$WEBAPP_CLIENT_SCOPES&state=12345" | pbcopy


### After login, capture the code from the redirect URI

export AUTH_CODE=1.AbcAI2epCrOYQkiWc3O6-q_ecM35PwNpYyRGn133E5-7AvxdAQC3AA.AgABBAIAAABVrSpeuWamRam2jAF1XRQEAwDs_wUA9P9KQt2-o6HhMPFW-Rgcv15V9XNJ8vzpIBiMt1yk2fNMOIMX1XiiAHFN_JqU6P4UhJGlJQD_zISZ50GCsbbTHu0XOA3cfY6DZQ94zYJ-n2yq4vDwQCSjTwDQ7By0t8seY1Ncuc1632Vy7OggV-EvKm-PsUQVrLIczZTd28ojqB9iLr8kPV0h1dHi9aZwbZo3qaOcbTZGqeIg1IOEGP2OXYf32qGMOrioh4LvuI4VdYjZotQpUl7kzHxl6btpjtyQOaxyG6Kc5aKo5gQsLelh6iKjeKtG_VoEMipyZbufyBQ6OKG-me8WhhqV4lIurqPTx0tffnteJsDTqc91IwA0ANrj634QCnMcWK0YAtEp3ygzyt4EZnhWJzNwYqIaFnCGW70cCllKCWcU1q1wMZCg63MaAGxsgRqQhjI7jDwuAa536WUEMyqRd3iuJWrqukcH2eCT1MA6_pE1zTNAsqfoDCYG2mSFX6l5DSoGxxfI8SoazsX-nACt7d9YwK4IQ7an2XUKKBOHo8kNlVi_CDFpBJcrz_P4yI1ANEVTjzKp9orC3GBpviPER1_a0zKmnGMGxVkyYb-MKsaBa5F3W02P1qlkVxNVMXIDxb3FIeCL4XxiE5XWRWsGRNq1u2uazJz3vEYhaOKFWTf8Zf3vjHP5LHBDaD5zbhDL8PezeQa8ENXuUO1YEqWMo-ehuU6WEbx8GU4IT2O7Na9Ow87DJ1FNIKCdICnIjHPlm_JW3bhLZeSyD1gx4GBawqv54h01TLCbxxtZQksJ1m01TW44419CtBk5rQ

## 2. Exchange Auth Code for Tokens (Web App)
export TOKENS=$(curl -s -X POST https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=${WEBAPP_CLIENT_ID}" -d "scope=${WEBAPP_CLIENT_SCOPES} openid" -d "code=${AUTH_CODE}" -d "redirect_uri=${WEBAPP_REDIRECT_URI}" -d "grant_type=authorization_code" -d "client_secret=${WEBAPP_CLIENT_SECRET}")

### This will return "access_token" and "id_token"
access_token=$(echo $TOKENS | jq .access_token -r)
jwt decode $access_token

###  3. OBO Token Exchange (Middle Tier)
### Use the access_token received above in assertion field:

export OBO_TOKENS=$(curl -s -X POST https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token -H "Content-Type: application/x-www-form-urlencoded" -d "client_id=$PRODUCTS_AGENT_CLIENT_ID" -d "client_secret=$PRODUCTS_AGENT_CLIENT_SECRET" -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer" -d "requested_token_use=on_behalf_of" -d "scope=$PRODUCTS_AGENT_SCOPES" -d "assertion=$access_token")

obo_access_token=$(echo $OBO_TOKENS | jq .access_token -r)
jwt decode $obo_access_token
echo $obo_access_token | pbcopy