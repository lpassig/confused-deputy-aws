# Microsoft Entra ID OAuth Streamlit Demo

A Streamlit application that demonstrates OAuth authentication with Microsoft Entra ID (formerly Azure AD). The application provides:

- OAuth login flow with Microsoft Entra ID
- JWT token display (both raw and decoded)
- Token refresh functionality
- Logout capability
- User-friendly interface

## Features

- ✅ **OAuth Authentication**: Secure login with Microsoft Entra ID
- 🔍 **JWT Token Analysis**: View raw and decoded JWT tokens
- 🔄 **Token Refresh**: Automatically refresh expired tokens
- 🚪 **Logout**: Clear session and logout functionality
- 📊 **Token Status**: Real-time token validity checking
- 🎨 **Modern UI**: Clean and intuitive Streamlit interface

## Prerequisites

- Python 3.12.8 or higher
- [uv](https://github.com/astral-sh/uv) package manager
- Microsoft Entra ID tenant (free tier available)
- App registration in Microsoft Entra ID

## Setup Instructions

### 1. Install uv (if not already installed)

```bash
# On macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# On Windows
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"

# Or with pip
pip install uv
```

### 2. Clone and Setup Environment

```bash
# Navigate to your project directory
cd /Users/ravipanchal/learn/vault/confused-deputy-aws/web

# Create virtual environment with Python 3.12.8
uv venv --python 3.12.8

# Activate the virtual environment
source .venv/bin/activate  # On Unix/macOS
# or
.venv\Scripts\activate     # On Windows

# Install dependencies from pyproject.toml
uv pip install streamlit streamlit-oauth "python-jose[cryptography]" python-dotenv requests cryptography

# Or install with development dependencies
uv pip install streamlit streamlit-oauth "python-jose[cryptography]" python-dotenv requests cryptography pytest black ruff mypy pre-commit
```

### 3. Microsoft Entra ID App Registration

Follow these steps to create an app registration in Microsoft Entra ID:

#### Step 1: Create App Registration
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** (or **Microsoft Entra ID**)
3. Go to **App registrations** → **New registration**
4. Fill in the details:
   - **Name**: `Streamlit OAuth Demo` (or your preferred name)
   - **Supported account types**: Choose based on your needs:
     - **Single tenant**: Only your organization
     - **Multi-tenant**: Any organizational directory
     - **Multi-tenant + personal**: Any organizational directory + personal Microsoft accounts
   - **Redirect URI**: Select **Web** and enter: `http://localhost:8501/oauth2callback`
5. Click **Register**

#### Step 2: Configure App Registration
1. After creation, note down the **Application (client) ID** and **Directory (tenant) ID**
2. Go to **Certificates & secrets** → **New client secret**
3. Add a description and choose expiration period
4. Copy the **client secret value** immediately (it won't be shown again)

#### Step 3: Configure API Permissions (Optional)
1. Go to **API permissions**
2. The following permissions are typically needed:
   - **Microsoft Graph**: `User.Read` (usually added by default)
   - **OpenID Connect**: `openid`, `profile`, `email`
3. Grant admin consent if required by your organization

### 4. Environment Configuration

Create a `.env` file based on the `.env.example` template:

```bash
cp .env.example .env
```

Fill in your actual values in the `.env` file:

```env
# Your Microsoft Entra ID configuration
CLIENT_ID=your_application_client_id_here
CLIENT_SECRET=your_client_secret_here
TENANT_ID=your_directory_tenant_id_here

# OAuth Scopes (space-separated)
SCOPE=openid profile email User.Read

# Redirect URI (must match what's in Azure App Registration)
REDIRECT_URI=http://localhost:8501/oauth2callback

# Base URL for Microsoft Entra ID (OAuth URLs will be constructed automatically)
BASE_URL=https://login.microsoftonline.com
```

**Note**: The OAuth URLs are now constructed automatically using the BASE_URL and TENANT_ID. Individual URL overrides are not supported - all URLs are dynamically generated.

### 5. Run the Application

```bash
# Make sure your virtual environment is activated
source .venv/bin/activate  # On Unix/macOS

# Run the Streamlit application
streamlit run app.py

# Alternative: Use the project script (if configured)
# oauth-demo
```

The application will start at `http://localhost:8501`

## Application Structure

```
/web
├── app.py                 # Main Streamlit application
├── pyproject.toml         # Project configuration and dependencies
├── .env.example          # Environment variables template
├── .env                  # Your actual environment variables (create this)
├── .venv/                # Virtual environment (created by uv)
├── .gitignore            # Git ignore rules
└── README.md             # This file
```

## Key Features Explained

### OAuth Flow
1. User clicks "Login with Microsoft"
2. Redirected to Microsoft Entra ID login page
3. After successful authentication, user is redirected back with authorization code
4. Application exchanges code for access and ID tokens
5. Tokens are stored in Streamlit session state

### JWT Token Display
- **Raw Token**: Shows the complete JWT token string
- **Decoded Token**: Displays header and payload in JSON format
- **Key Information**: Highlights important claims like user info, expiration, etc.
- **Token Status**: Shows if token is valid or expired

### Token Management
- **Automatic Refresh**: Tokens can be refreshed when expired
- **Session Persistence**: Tokens persist during the browser session
- **Secure Logout**: Clears all session data

## Security Considerations

⚠️ **Important Security Notes:**

1. **Client Secret**: Never commit your `.env` file to version control
2. **HTTPS in Production**: Always use HTTPS in production environments
3. **Token Validation**: This demo shows tokens without signature verification - implement proper validation in production
4. **Scope Limitation**: Only request the minimum scopes needed for your application
5. **Token Storage**: Consider more secure token storage for production applications

## Troubleshooting

### Common Issues

1. **"Missing required environment variables"**
   - Ensure your `.env` file exists and contains all required variables
   - Check that variable names match exactly

2. **OAuth callback error**
   - Verify the redirect URI in your `.env` matches the one in Azure App Registration
   - Ensure the application is running on the correct port (8501)

3. **Token decoding errors**
   - This usually means the JWT token format is invalid
   - Check if you're using the correct token type (access_token vs id_token)

4. **Permission denied errors**
   - Check that your app registration has the required API permissions
   - Ensure admin consent is granted if required by your organization

### Debug Mode

To enable debug information, you can add this to your `.env`:

```env
STREAMLIT_LOGGER_LEVEL=debug
```

## Development Workflow

### Code Quality Tools

This project includes several code quality tools configured in `pyproject.toml`:

```bash
# Format code with Black
uv run black app.py

# Lint with Ruff
uv run ruff check app.py

# Type checking with MyPy
uv run mypy app.py

# Run tests
uv run pytest
```

### Pre-commit Hooks

```bash
# Install pre-commit hooks (optional)
uv run pre-commit install

# Run hooks manually
uv run pre-commit run --all-files
```

## Customization

You can customize the application by:

1. **Modifying Scopes**: Update the `SCOPE` variable in `.env`
2. **Changing UI**: Modify the Streamlit components in `app.py`
3. **Adding Features**: Extend the token analysis or add API calls using the access token
4. **Styling**: Use Streamlit's theming capabilities or custom CSS
5. **Dependencies**: Add new dependencies with `uv add <package-name>`

## Dependencies

This project uses modern Python packaging with `pyproject.toml` and `uv` for fast dependency management.

### Core Dependencies
- `streamlit>=1.32.0`: Web framework for the UI
- `streamlit-oauth>=0.1.7`: OAuth2 component for Streamlit
- `python-jose[cryptography]>=3.3.0`: JWT token handling
- `python-dotenv>=1.0.0`: Environment variable loading
- `requests>=2.31.0`: HTTP requests
- `cryptography>=41.0.0`: Cryptographic operations

### Development Dependencies (optional)
- `pytest>=7.0.0`: Testing framework
- `black>=23.0.0`: Code formatting
- `ruff>=0.1.0`: Fast Python linter
- `mypy>=1.0.0`: Static type checking
- `pre-commit>=3.0.0`: Git hooks

### Managing Dependencies

```bash
# Install production dependencies
uv pip install streamlit streamlit-oauth "python-jose[cryptography]" python-dotenv requests cryptography

# Add a new dependency
uv pip install <package-name>

# List installed packages
uv pip list

# Create/update a lockfile (if needed)
uv pip freeze > requirements-lock.txt
```

## License

This is a demonstration application. Feel free to use and modify as needed.

## Support

For issues related to:
- **Streamlit**: Check the [Streamlit documentation](https://docs.streamlit.io)
- **Microsoft Entra ID**: Refer to [Microsoft Identity platform documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/)
- **OAuth2**: See the [OAuth 2.0 specification](https://oauth.net/2/)

---

**Note**: This is a demo application for learning purposes. For production use, implement additional security measures and follow your organization's security policies.
