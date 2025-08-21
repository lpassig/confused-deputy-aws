# OAuth2 Flow Test Script

This directory contains a simple Python test script that demonstrates the OAuth2 flow with Microsoft Entra ID, including on-behalf-of token exchange.

## Files

- `test_oauth2_flow.py` - Main test script
- `requirements.txt` - Python dependencies
- `setup_env_template.sh` - Template for environment variable setup
- `oauth2_entra_flow.md` - Manual flow documentation

## Prerequisites

1. **Python 3.6+** with pip installed
2. **Azure AD Applications** configured:
   - Web App registration for user authentication
   - Products Agent registration for on-behalf-of flow
3. **Environment variables** set (see setup below)

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Copy and customize the environment setup script:

```bash
cp setup_env_template.sh setup_env.sh
# Edit setup_env.sh with your actual Azure AD app details
source setup_env.sh
```

Or set them manually:

```bash
export TENANT_ID="your-tenant-id"
export WEBAPP_CLIENT_ID="your-webapp-client-id"
export WEBAPP_CLIENT_SECRET="your-webapp-client-secret"
export WEBAPP_CLIENT_SCOPES="openid profile email your-custom-scopes"
export PRODUCTS_AGENT_CLIENT_ID="your-products-agent-client-id"
export PRODUCTS_AGENT_CLIENT_SECRET="your-products-agent-client-secret"
export PRODUCTS_AGENT_SCOPES="your-agent-scopes"
```

## Usage

### Run the Test Script

```bash
python test_oauth2_flow.py
```

### What the Script Does

1. **Environment Check**: Validates all required environment variables are set
2. **User Authentication**: 
   - Starts a local HTTP server on port 8501 for OAuth2 callback
   - Opens browser for Microsoft Entra ID login
   - Exchanges authorization code for user access token
3. **On-Behalf-Of Flow**:
   - Uses the user token to request an on-behalf-of token
   - Exchanges tokens using the Products Agent credentials
4. **Token Display**:
   - Decodes and displays JWT payloads for both tokens
   - Provides full tokens in environment variable format

### Expected Output

```
🚀 OAuth2 Flow Test Script
==================================================
✅ All required environment variables are set

🔐 Step 1: User Authentication
📡 Started callback server on http://localhost:8501
🌐 Opening browser for authentication...
⏳ Waiting for authentication callback...
✅ Received authorization code: ABC123...
🔄 Exchanging authorization code for tokens...
✅ Successfully obtained user access token

📋 User Token Payload:
{
  "aud": "your-audience",
  "iss": "https://login.microsoftonline.com/...",
  "sub": "user-subject-id",
  ...
}

🔄 Step 2: On-Behalf-Of Token Exchange
🔄 Requesting on-behalf-of token...
✅ Successfully obtained on-behalf-of token

📋 OBO Token Payload:
{
  "aud": "your-api-audience",
  "iss": "https://login.microsoftonline.com/...",
  "sub": "user-subject-id",
  ...
}

==================================================
✅ OAuth2 Flow Completed Successfully!
==================================================

📄 User Access Token:
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6...

📄 OBO Access Token:
eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6...
```

## Troubleshooting

### Common Issues

1. **Missing Environment Variables**: Ensure all required variables are set
2. **Port 8501 in Use**: Stop any process using port 8501 or modify the script
3. **Browser Not Opening**: Manually copy the auth URL from the console
4. **Token Exchange Fails**: Check Azure AD app permissions and configurations

### Azure AD App Configuration

Make sure your Azure AD applications have:

- **Web App**: 
  - Redirect URI: `http://localhost:8501/oauth2callback`
  - Required permissions for requested scopes
  
- **Products Agent**:
  - API permissions to access the target resources
  - Proper application roles configured

## Security Notes

⚠️ **This script is for testing purposes only**

- Never use hardcoded credentials in production
- The callback server runs on localhost without HTTPS
- Tokens are displayed in console output
- Environment variables may be visible in process lists

For production use, implement proper security practices including HTTPS, secure token storage, and proper error handling.