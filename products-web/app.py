import base64
import json
import os
import requests
from datetime import datetime, timezone
from typing import Dict, List, Optional, Tuple

import streamlit as st
import streamlit.components.v1 as components
from dotenv import load_dotenv
from jose import JWTError, jwt
from streamlit_oauth import OAuth2Component

# Load environment variables
load_dotenv()

# Configuration
st.set_page_config(
    page_title="Microsoft Entra ID OAuth & ProductsAgent Chat",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Custom CSS for better styling
st.markdown(
    """
<style>
.logout-button {
    position: fixed;
    top: 4rem;
    right: 1rem;
    z-index: 999;
}

.chat-message {
    padding: 1rem;
    border-radius: 0.5rem;
    margin: 0.5rem 0;
    border-left: 4px solid #007acc;
}

.user-message {
    background-color: #f0f2f6;
    border-left-color: #007acc;
}

.agent-message {
    background-color: #e8f4f8;
    border-left-color: #28a745;
}

.error-message {
    background-color: #ffeaea;
    border-left-color: #dc3545;
}

.token-valid {
    color: #28a745;
    font-weight: bold;
}

.token-expired {
    color: #dc3545;
    font-weight: bold;
}

.status-panel {
    background-color: #f8f9fa;
    border: 1px solid #dee2e6;
    border-radius: 0.375rem;
    padding: 1rem;
    margin-bottom: 1rem;
}

.chat-container {
    height: 50vh; /* Reduced from 60vh */
    max-height: 500px; /* Reduced from 600px */
    min-height: 250px; /* Reduced from 300px */
    overflow-y: auto;
    border: 1px solid #dee2e6;
    border-radius: 0.375rem;
    padding: 1rem;
    background-color: #ffffff;
    margin-bottom: 1rem;
    display: flex;
    flex-direction: column;
}

.chat-history {
    flex-grow: 1;
    overflow-y: auto;
    padding-right: 0.5rem;
}

.chat-history::-webkit-scrollbar {
    width: 8px;
}

.chat-history::-webkit-scrollbar-track {
    background: #f1f1f1;
    border-radius: 4px;
}

.chat-history::-webkit-scrollbar-thumb {
    background: #c1c1c1;
    border-radius: 4px;
}

.chat-history::-webkit-scrollbar-thumb:hover {
    background: #a8a8a8;
}

.chat-input-container {
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid #dee2e6;
}

.main-content {
    margin-top: 2rem;
}
</style>
""",
    unsafe_allow_html=True,
)

# Environment variables
CLIENT_ID = os.environ.get("CLIENT_ID")
CLIENT_SECRET = os.environ.get("CLIENT_SECRET")
TENANT_ID = os.environ.get("TENANT_ID")
SCOPE = os.environ.get("SCOPE", "openid profile email User.Read")
REDIRECT_URI = os.environ.get("REDIRECT_URI", "http://localhost:8501/oauth2callback")
BASE_URL = os.environ.get("BASE_URL", "https://login.microsoftonline.com")
PRODUCTS_AGENT_URL = os.environ.get("PRODUCTS_AGENT_URL", "http://localhost:8000")

# Construct OAuth URLs dynamically from base URL and tenant ID
if TENANT_ID and BASE_URL:
    # Always construct URLs dynamically - no environment variable overrides
    AUTHORIZE_URL = f"{BASE_URL}/{TENANT_ID}/oauth2/v2.0/authorize"
    TOKEN_URL = f"{BASE_URL}/{TENANT_ID}/oauth2/v2.0/token"
    REFRESH_TOKEN_URL = f"{BASE_URL}/{TENANT_ID}/oauth2/v2.0/token"
    # Microsoft Entra ID doesn't have a standard token revocation endpoint
    REVOKE_TOKEN_URL = None
else:
    AUTHORIZE_URL = TOKEN_URL = REFRESH_TOKEN_URL = REVOKE_TOKEN_URL = None

# Initialize session state for chat
if "chat_messages" not in st.session_state:
    st.session_state.chat_messages = []

if "api_status" not in st.session_state:
    st.session_state.api_status = None


def decode_jwt_token(
    token_string: str,
) -> Tuple[Optional[Dict], Optional[Dict], Optional[str]]:
    """Decode JWT token and return header, payload, and error message"""
    try:
        parts = token_string.split(".")
        if len(parts) != 3:
            return None, None, "Invalid JWT token format"

        header = json.loads(base64.urlsafe_b64decode(parts[0] + "==").decode("utf-8"))
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + "==").decode("utf-8"))

        return header, payload, None
    except Exception as e:
        return None, None, f"Error decoding token: {str(e)}"


def format_timestamp(timestamp: Optional[int]) -> str:
    """Convert Unix timestamp to readable format"""
    if timestamp:
        return datetime.fromtimestamp(timestamp, tz=timezone.utc).strftime(
            "%Y-%m-%d %H:%M:%S UTC"
        )
    return "N/A"


def get_token_info(token_data: Dict) -> Tuple[bool, str, Optional[Dict]]:
    """Get token validity and user info"""
    if not token_data:
        return False, "No token available", None

    access_token = token_data.get("access_token")
    if not access_token:
        return False, "No access token available", None

    _, payload, error = decode_jwt_token(access_token)
    if error or not payload:
        return False, f"Token decode error: {error}", None

    exp_time = payload.get("exp")
    if not exp_time:
        return True, "Token valid (no expiry found)", payload

    current_time = datetime.now(timezone.utc).timestamp()
    if exp_time > current_time:
        exp_readable = format_timestamp(exp_time)
        return True, f"Token valid until {exp_readable}", payload
    else:
        exp_readable = format_timestamp(exp_time)
        return False, f"Token expired at {exp_readable}", payload


def call_products_agent(prompt: str, access_token: str) -> Tuple[bool, str]:
    """Call the ProductsAgent API with user prompt"""
    try:
        headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }

        payload = {"prompt": prompt}

        response = requests.post(
            f"{PRODUCTS_AGENT_URL}/agent/invoke",
            headers=headers,
            json=payload,
            timeout=30,
        )

        if response.status_code == 200:
            data = response.json()
            return True, data.get("response", "No response from agent")
        else:
            error_data = response.json() if response.content else {}
            error_msg = error_data.get("detail", f"HTTP {response.status_code}")
            return False, f"API Error: {error_msg}"

    except requests.exceptions.Timeout:
        return (
            False,
            "Request timed out. The agent might be processing a complex request.",
        )
    except requests.exceptions.ConnectionError:
        return (
            False,
            f"Cannot connect to ProductsAgent API at {PRODUCTS_AGENT_URL}. Please ensure the API is running.",
        )
    except Exception as e:
        return False, f"Unexpected error: {str(e)}"


def check_api_health() -> bool:
    """Check if the ProductsAgent API is available"""
    try:
        response = requests.get(f"{PRODUCTS_AGENT_URL}/health", timeout=5)
        return response.status_code == 200
    except:
        return False


def render_chat_message(message: Dict, key: str):
    """Render a chat message with proper styling"""
    is_user = message["type"] == "user"
    is_error = message.get("error", False)

    if is_error:
        css_class = "error-message"
        icon = "❌"
    elif is_user:
        css_class = "user-message"
        icon = "👤"
    else:
        css_class = "agent-message"
        icon = "🤖"

    timestamp = message.get("timestamp", "")

    st.markdown(
        f"""
    <div class="chat-message {css_class}">
        <strong>{icon} {message["type"].title()}</strong> 
        <small style="color: #666; margin-left: 10px;">{timestamp}</small>
        <br><br>
        {message["content"]}
    </div>
    """,
        unsafe_allow_html=True,
    )


def logout():
    """Clear session state and logout user"""
    for key in list(st.session_state.keys()):
        del st.session_state[key]
    st.rerun()


def render_auth_status_panel():
    """Render authentication status in sidebar"""
    with st.sidebar:
        st.header("🔐 Authentication Status")

        if "token" in st.session_state:
            token = st.session_state["token"]
            is_valid, status_msg, payload = get_token_info(token)

            if is_valid:
                st.success("✅ Authenticated")
                st.markdown(
                    f'<p class="token-valid">{status_msg}</p>', unsafe_allow_html=True
                )
            else:
                st.error("❌ Token Issue")
                st.markdown(
                    f'<p class="token-expired">{status_msg}</p>', unsafe_allow_html=True
                )

            if payload:
                st.write("**User Info:**")
                if "name" in payload:
                    st.write(f"**Name:** {payload['name']}")
                if "upn" in payload:
                    st.write(f"**UPN:** {payload['upn']}")
                if "unique_name" in payload:
                    st.write(f"**Email:** {payload['unique_name']}")

            # Token actions
            col1, col2 = st.columns(2)
            with col1:
                if st.button("🔄 Refresh", use_container_width=True):
                    try:
                        oauth2 = OAuth2Component(
                            client_id=CLIENT_ID,
                            client_secret=CLIENT_SECRET,
                            authorize_endpoint=AUTHORIZE_URL,
                            token_endpoint=TOKEN_URL,
                            refresh_token_endpoint=REFRESH_TOKEN_URL,
                            revoke_token_endpoint=REVOKE_TOKEN_URL,
                        )
                        refreshed_token = oauth2.refresh_token(token)
                        st.session_state.token = refreshed_token
                        st.success("Token refreshed!")
                        st.rerun()
                    except Exception as e:
                        st.error(f"Refresh failed: {str(e)}")

            with col2:
                if st.button("🚪 Logout", use_container_width=True):
                    logout()


def render_token_details():
    """Render detailed token information"""
    if "token" not in st.session_state:
        return

    st.header("🔍 Token Information")
    token = st.session_state["token"]

    with st.expander("📋 Raw Token Data", expanded=False):
        st.json(token)

    access_token = token.get("access_token")
    if access_token:
        with st.expander("🔑 Access Token Details", expanded=False):
            header, payload, error = decode_jwt_token(access_token)
            if error:
                st.error(error)
            else:
                col1, col2 = st.columns(2)
                with col1:
                    st.subheader("Header")
                    st.json(header)
                with col2:
                    st.subheader("Payload")
                    if payload:
                        # Add readable timestamps
                        formatted_payload = payload.copy()
                        for time_field in ["exp", "iat", "nbf", "auth_time"]:
                            if time_field in formatted_payload:
                                formatted_payload[f"{time_field}_readable"] = (
                                    format_timestamp(formatted_payload[time_field])
                                )
                        st.json(formatted_payload)


def render_chat_interface():
    """Render the agentic chat interface"""
    st.header("🤖 Vault-Powered Agent")

    # Check API health
    if st.session_state.api_status is None:
        with st.spinner("Checking Agent API..."):
            st.session_state.api_status = check_api_health()

    if not st.session_state.api_status:
        st.error(f"⚠️ Agent API is not available at {PRODUCTS_AGENT_URL}")
        st.info("Please ensure the Agent API is running and accessible.")
        if st.button("🔄 Retry Connection"):
            st.session_state.api_status = None
            st.rerun()
        return
    else:
        st.success(f"✅ ProductsAgent API is available at {PRODUCTS_AGENT_URL}")

    # Chat History using Streamlit's native chat interface
    st.markdown("### 💬 Chat History")

    # Create a container for chat messages with fixed height and scrolling
    chat_container = st.container(height=400, border=True)

    with chat_container:
        if st.session_state.chat_messages:
            for message in st.session_state.chat_messages:
                is_user = message["type"] == "user"
                is_error = message.get("error", False)
                timestamp = message.get("timestamp", "")

                if is_error:
                    # Show error messages differently
                    st.error(
                        f"❌ **System Error** ({timestamp})\n\n{message['content']}"
                    )
                elif is_user:
                    # User message
                    with st.chat_message("user"):
                        st.write(f"**{timestamp}**")
                        st.write(message["content"])
                else:
                    # Agent message
                    with st.chat_message("assistant"):
                        st.write(f"**{timestamp}**")
                        st.write(message["content"])
        else:
            # Empty state
            st.info("💬 No messages yet. Start a conversation with the ProductsAgent!")

    # Clear chat button and example queries
    col1, col2, col3 = st.columns([1, 1, 2])
    with col1:
        if st.session_state.chat_messages and st.button(
            "🗑️ Clear Chat History", use_container_width=True
        ):
            st.session_state.chat_messages = []
            st.rerun()

    with col2:
        with st.expander("💡 Example Queries", expanded=False):
            st.markdown("""
            **Product Queries:**
            - "List all products"
            - "Show products matching laptop"
            - "Find products under $100"
            - "Create a new product named 'Wireless Mouse' priced at 29.99"
            - "Update product 123 with price 199.99"
            - "Delete product with ID 456"
            - "Show product details for ID 789"
            
            **General Questions:**
            - "How many products are in the catalog?"
            - "What's the most expensive product?"
            - "Show me products in the electronics category"
            """)

    # Handle user input at the bottom of the page
    user_input = st.chat_input(
        "Ask about products (e.g., 'list all products', 'show products matching laptop', 'create a new product priced at 500.99')"
    )

    if user_input:
        # Add user message
        timestamp = datetime.now().strftime("%H:%M:%S")
        user_message = {"type": "user", "content": user_input, "timestamp": timestamp}
        st.session_state.chat_messages.append(user_message)

        # Get access token
        if "token" not in st.session_state:
            error_message = {
                "type": "system",
                "content": "Authentication required. Please log in first.",
                "timestamp": timestamp,
                "error": True,
            }
            st.session_state.chat_messages.append(error_message)
        else:
            access_token = st.session_state["token"].get("access_token")
            # Check if access_token is valid and not expired
            _, status_msg, payload = get_token_info({"access_token": access_token})
            if "expired" in status_msg.lower():
                error_message = {
                    "type": "system",
                    "content": f"Access token expired. Please refresh your authentication. ({status_msg})",
                    "timestamp": timestamp,
                    "error": True,
                }
                st.session_state.chat_messages.append(error_message)
                st.rerun()
            if not access_token:
                error_message = {
                    "type": "system",
                    "content": "No access token available. Please refresh your authentication.",
                    "timestamp": timestamp,
                    "error": True,
                }
                st.session_state.chat_messages.append(error_message)
            else:
                # Call the agent API
                with st.spinner("🤖 ProductsAgent is thinking..."):
                    success, response = call_products_agent(user_input, access_token)

                agent_message = {
                    "type": "agent" if success else "system",
                    "content": response,
                    "timestamp": datetime.now().strftime("%H:%M:%S"),
                    "error": not success,
                }
                st.session_state.chat_messages.append(agent_message)

        st.rerun()


def main():
    # Header with logout button
    col1, col2 = st.columns([4, 1])
    with col1:
        st.title("🫆 Secure Agentic Demo: HCP Vault x Bedrock x Entra ID ")
    with col2:
        if "token" in st.session_state:
            st.markdown('<div class="logout-button">', unsafe_allow_html=True)
            if st.button("🚪 Logout", key="header_logout"):
                logout()
            st.markdown("</div>", unsafe_allow_html=True)

    st.markdown("---")

    # Check configuration
    missing_config = []
    if not CLIENT_ID:
        missing_config.append("CLIENT_ID")
    if not CLIENT_SECRET:
        missing_config.append("CLIENT_SECRET")
    if not TENANT_ID:
        missing_config.append("TENANT_ID")

    if missing_config:
        st.error(f"Missing required environment variables: {', '.join(missing_config)}")
        st.info(
            "Please create a .env file based on .env.example and fill in your Microsoft Entra ID configuration."
        )
        st.stop()

    # Authentication flow
    if "token" not in st.session_state:
        st.header("🚪 Authentication Required")
        st.write(
            "Please authenticate with Microsoft Entra ID to access the ProductsAgent chat."
        )

        with st.expander("ℹ️ Configuration Details", expanded=False):
            st.write(f"**Client ID:** {CLIENT_ID}")
            st.write(f"**Tenant ID:** {TENANT_ID}")
            st.write(f"**Base URL:** {BASE_URL}")
            st.write(f"**Scopes:** {SCOPE}")
            st.write(f"**Products API:** {PRODUCTS_AGENT_URL}")

        # Create OAuth2Component instance
        oauth2 = OAuth2Component(
            client_id=CLIENT_ID,
            client_secret=CLIENT_SECRET,
            authorize_endpoint=AUTHORIZE_URL,
            token_endpoint=TOKEN_URL,
            refresh_token_endpoint=REFRESH_TOKEN_URL,
            revoke_token_endpoint=REVOKE_TOKEN_URL,
        )

        # Authorization button
        result = oauth2.authorize_button(
            "Login with Microsoft",
            REDIRECT_URI,
            SCOPE,
            height=600,
            width=500,
            key="auth_button",
            use_container_width=True,
        )

        if result and "token" in result:
            st.session_state.token = result.get("token")
            st.success("Successfully authenticated!")
            st.rerun()
    else:
        # User is logged in - show main interface
        render_auth_status_panel()

        # Main content area
        st.markdown('<div class="main-content">', unsafe_allow_html=True)

        # Create tabs for different sections
        tab1, tab2 = st.tabs(["🤖 Chat", "🔍 Token Information"])

        with tab1:
            render_chat_interface()

        with tab2:
            render_token_details()

        st.markdown("</div>", unsafe_allow_html=True)


if __name__ == "__main__":
    main()
