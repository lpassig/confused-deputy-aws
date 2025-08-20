# Quick Start Guide

## 🚀 Get Running in 5 Minutes

### 1. Setup Environment
```bash
# Create and activate virtual environment
uv venv --python 3.12.8
source .venv/bin/activate

# Install dependencies
uv pip install streamlit streamlit-oauth "python-jose[cryptography]" python-dotenv requests cryptography
```

### 2. Configure Environment
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your Microsoft Entra ID credentials:
# CLIENT_ID, CLIENT_SECRET, TENANT_ID
```

### 3. Run Application
```bash
# Start the Streamlit app
streamlit run app.py
```

### 4. Open Browser
Navigate to `http://localhost:8501` and test the OAuth flow!

## 📋 Prerequisites Checklist

- [ ] Python 3.12.8+ installed
- [ ] uv package manager installed (`pip install uv`)
- [ ] Microsoft Entra ID app registration created
- [ ] Redirect URI set to `http://localhost:8501/oauth2callback`

## ⚡ Key Commands

```bash
# Create virtual environment
uv venv --python 3.12.8

# Install dependencies
uv pip install streamlit streamlit-oauth "python-jose[cryptography]" python-dotenv requests cryptography

# Run the application
streamlit run app.py

# Format code (if dev dependencies installed)
uv run black app.py

# Lint code (if dev dependencies installed)  
uv run ruff check app.py
```

## 🔧 Environment Variables Required

```env
CLIENT_ID=your_client_id_here
CLIENT_SECRET=your_client_secret_here  
TENANT_ID=your_tenant_id_here
SCOPE=openid profile email User.Read
REDIRECT_URI=http://localhost:8501/oauth2callback
BASE_URL=https://login.microsoftonline.com
PRODUCTS_API_BASE_URL=http://localhost:8000
```

## 🤖 New Features

- **Enhanced UI Layout**: Authentication status in sidebar, logout button at top right
- **Agentic Chat Interface**: Chat with ProductsAgent API using natural language
- **Token Information Panel**: Detailed JWT token analysis in separate tab
- **API Health Checking**: Automatic verification of ProductsAgent API availability

For detailed setup instructions, see [README.md](README.md).
