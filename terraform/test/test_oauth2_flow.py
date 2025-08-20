#!/usr/bin/env python3
"""
Simple test script for OAuth2 flow with Microsoft Entra ID
Includes user authentication and on-behalf-of token exchange
"""

import os
import sys
import json
import base64
import urllib.parse
import webbrowser
import subprocess
import platform
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread
import requests

# Configuration from environment variables
TENANT_ID = os.getenv("TENANT_ID")
WEBAPP_CLIENT_ID = os.getenv("WEBAPP_CLIENT_ID")
WEBAPP_CLIENT_SECRET = os.getenv("WEBAPP_CLIENT_SECRET")
WEBAPP_CLIENT_SCOPES = os.getenv("WEBAPP_CLIENT_SCOPES")

PRODUCTS_AGENT_CLIENT_ID = os.getenv("PRODUCTS_AGENT_CLIENT_ID")
PRODUCTS_AGENT_CLIENT_SECRET = os.getenv("PRODUCTS_AGENT_CLIENT_SECRET")
PRODUCTS_AGENT_SCOPES = os.getenv("PRODUCTS_AGENT_SCOPES")

REDIRECT_URI = "http://localhost:8501/oauth2callback"

# Global variable to store the authorization code
auth_code = None
server_running = True


class CallbackHandler(BaseHTTPRequestHandler):
    """HTTP server to handle OAuth2 callback"""

    def do_GET(self):
        global auth_code, server_running

        if self.path.startswith("/oauth2callback"):
            # Parse the query parameters
            query = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(query)

            if "code" in params:
                auth_code = params["code"][0]
                self.send_response(200)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(
                    b"<html><body><h1>Authentication successful!</h1><p>You can close this window.</p></body></html>"
                )
                server_running = False
            else:
                self.send_response(400)
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write(
                    b"<html><body><h1>Authentication failed!</h1></body></html>"
                )
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress default logging
        pass


def decode_jwt_payload(token):
    """Decode JWT payload for display"""
    try:
        # Split the token and get the payload part
        parts = token.split(".")
        if len(parts) != 3:
            return "Invalid JWT format"

        # Add padding if needed
        payload = parts[1]
        payload += "=" * (4 - len(payload) % 4)

        # Decode base64
        decoded = base64.urlsafe_b64decode(payload)
        return json.dumps(json.loads(decoded), indent=2)
    except Exception as e:
        return f"Error decoding JWT: {str(e)}"


def check_environment_variables():
    """Check if all required environment variables are set"""
    required_vars = [
        "TENANT_ID",
        "WEBAPP_CLIENT_ID",
        "WEBAPP_CLIENT_SECRET",
        "WEBAPP_CLIENT_SCOPES",
        "PRODUCTS_AGENT_CLIENT_ID",
        "PRODUCTS_AGENT_CLIENT_SECRET",
        "PRODUCTS_AGENT_SCOPES",
    ]

    missing_vars = []
    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)

    if missing_vars:
        print("❌ Missing required environment variables:")
        for var in missing_vars:
            print(f"   - {var}")
        print("\nPlease set these environment variables and run the script again.")
        sys.exit(1)

    print("✅ All required environment variables are set")


def start_callback_server():
    """Start HTTP server to handle OAuth2 callback"""
    server = HTTPServer(("localhost", 8501), CallbackHandler)
    server_thread = Thread(target=lambda: server.serve_forever())
    server_thread.daemon = True
    server_thread.start()
    return server


def open_browser_incognito(url):
    """Open browser in new incognito/private window"""
    system = platform.system().lower()
    print(f"🖥️  Detected OS: {system}")

    try:
        if system == "darwin":  # macOS
            # Try Chrome first - force new window
            try:
                print("🔍 Trying Google Chrome with new incognito window...")
                subprocess.run(
                    [
                        "open",
                        "-na",
                        "Google Chrome",
                        "--args",
                        "--incognito",
                        "--new-window",
                        url,
                    ],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                print("✅ Successfully opened Chrome in new incognito window")
                return True
            except subprocess.CalledProcessError as e:
                print(f"❌ Chrome failed: {e}")
            except FileNotFoundError:
                print("❌ Chrome not found")

            # Try Safari with AppleScript for new private window
            try:
                print("🔍 Trying Safari with new private window...")
                applescript = f'''
                tell application "Safari"
                    activate
                    tell application "System Events"
                        keystroke "n" using {{shift down, command down}}
                    end tell
                    delay 0.5
                    set URL of front document to "{url}"
                end tell
                '''
                subprocess.run(
                    ["osascript", "-e", applescript],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                print("✅ Successfully opened Safari in new private window")
                return True
            except subprocess.CalledProcessError as e:
                print(f"❌ Safari failed: {e}")
            except FileNotFoundError:
                print("❌ Safari/osascript not found")

            # Try Firefox with new private window
            try:
                print("🔍 Trying Firefox with new private window...")
                subprocess.run(
                    [
                        "/Applications/Firefox.app/Contents/MacOS/firefox",
                        "--new-window",
                        "--private-window",
                        url,
                    ],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                print("✅ Successfully opened Firefox in new private window")
                return True
            except subprocess.CalledProcessError as e:
                print(f"❌ Firefox failed: {e}")
            except FileNotFoundError:
                print("❌ Firefox not found")

        elif system == "windows":
            # Try Chrome with new window
            try:
                print("🔍 Trying Chrome with new incognito window...")
                subprocess.run(
                    [
                        "cmd",
                        "/c",
                        "start",
                        "",
                        "chrome.exe",
                        "--incognito",
                        "--new-window",
                        url,
                    ],
                    check=True,
                )
                print("✅ Successfully opened Chrome in new incognito window")
                return True
            except (subprocess.CalledProcessError, FileNotFoundError) as e:
                print(f"❌ Chrome failed: {e}")

            # Try Edge with new window
            try:
                print("🔍 Trying Edge with new inprivate window...")
                subprocess.run(
                    [
                        "cmd",
                        "/c",
                        "start",
                        "",
                        "msedge.exe",
                        "--inprivate",
                        "--new-window",
                        url,
                    ],
                    check=True,
                )
                print("✅ Successfully opened Edge in new inprivate window")
                return True
            except (subprocess.CalledProcessError, FileNotFoundError) as e:
                print(f"❌ Edge failed: {e}")

        elif system == "linux":
            # Try Chrome/Chromium with new window
            for browser in ["google-chrome", "chromium-browser", "chromium"]:
                try:
                    print(f"🔍 Trying {browser} with new incognito window...")
                    subprocess.run(
                        [browser, "--incognito", "--new-window", url], check=True
                    )
                    print(f"✅ Successfully opened {browser} in new incognito window")
                    return True
                except (subprocess.CalledProcessError, FileNotFoundError) as e:
                    print(f"❌ {browser} failed: {e}")
                    continue

            # Try Firefox with new private window
            try:
                print("🔍 Trying Firefox with new private window...")
                subprocess.run(
                    ["firefox", "--new-window", "--private-window", url], check=True
                )
                print("✅ Successfully opened Firefox in new private window")
                return True
            except (subprocess.CalledProcessError, FileNotFoundError) as e:
                print(f"❌ Firefox failed: {e}")

        # If all incognito attempts fail, fall back to default browser
        print("⚠️  All incognito attempts failed, falling back to default browser")
        webbrowser.open_new(url)  # Use open_new for new window/tab
        print("✅ Opened in default browser (regular mode, new window/tab)")
        return False

    except Exception as e:
        print(f"⚠️  Error opening browser: {e}")
        print("⚠️  Falling back to default browser")
        webbrowser.open_new(url)  # Use open_new for new window/tab
        print("✅ Opened in default browser (regular mode, new window/tab)")
        return False


def get_user_token():
    """Step 1: Get user authorization code and exchange for tokens"""
    print("\n🔐 Step 1: User Authentication")

    # Start callback server
    server = start_callback_server()
    print("📡 Started callback server on http://localhost:8501")

    # Construct authorization URL
    auth_url = (
        f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/authorize?"
        f"client_id={WEBAPP_CLIENT_ID}&"
        f"response_type=code&"
        f"redirect_uri={urllib.parse.quote(REDIRECT_URI)}&"
        f"response_mode=query&"
        f"scope={urllib.parse.quote(WEBAPP_CLIENT_SCOPES)}&"
        f"state=12345"
    )

    print("🌐 Opening browser in incognito mode for authentication...")
    print(f"Auth URL: {auth_url}")

    # Open browser in incognito mode for authentication
    incognito_success = open_browser_incognito(auth_url)
    if incognito_success:
        print("✅ Browser opened successfully")
    else:
        print("⚠️  Browser opened in regular mode")

    # Also provide manual instructions in case browser doesn't open
    print("\n" + "=" * 60)
    print("📋 MANUAL AUTHENTICATION INSTRUCTIONS:")
    print("If the browser didn't open automatically, please:")
    print("1. Copy the URL above")
    print("2. Open your browser in incognito/private mode")
    print("3. Paste and visit the URL")
    print("4. Complete the authentication")
    print("=" * 60)

    # Wait for callback
    print("⏳ Waiting for authentication callback...")
    while server_running and auth_code is None:
        import time

        time.sleep(0.1)

    server.shutdown()

    if not auth_code:
        print("❌ Failed to receive authorization code")
        sys.exit(1)

    print(f"✅ Received authorization code: {auth_code[:20]}...")

    # Exchange authorization code for tokens
    token_url = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"

    token_data = {
        "client_id": WEBAPP_CLIENT_ID,
        "scope": WEBAPP_CLIENT_SCOPES,
        "code": auth_code,
        "redirect_uri": REDIRECT_URI,
        "grant_type": "authorization_code",
        "client_secret": WEBAPP_CLIENT_SECRET,
    }

    print("🔄 Exchanging authorization code for tokens...")

    response = requests.post(token_url, data=token_data)

    if response.status_code != 200:
        print(f"❌ Failed to get tokens: {response.status_code}")
        print(f"Response: {response.text}")
        sys.exit(1)

    tokens = response.json()
    access_token = tokens.get("access_token")

    if not access_token:
        print("❌ No access token received")
        print(f"Response: {json.dumps(tokens, indent=2)}")
        sys.exit(1)

    print("✅ Successfully obtained user access token")
    print(f"\n📋 User Token Payload:")
    print(decode_jwt_payload(access_token))

    return access_token


def get_obo_token(user_token):
    """Step 2: Exchange user token for on-behalf-of token"""
    print("\n🔄 Step 2: On-Behalf-Of Token Exchange")

    token_url = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"

    obo_data = {
        "client_id": PRODUCTS_AGENT_CLIENT_ID,
        "client_secret": PRODUCTS_AGENT_CLIENT_SECRET,
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "requested_token_use": "on_behalf_of",
        "scope": PRODUCTS_AGENT_SCOPES,
        "assertion": user_token,
    }

    print("🔄 Requesting on-behalf-of token...")

    response = requests.post(token_url, data=obo_data)

    if response.status_code != 200:
        print(f"❌ Failed to get OBO token: {response.status_code}")
        print(f"Response: {response.text}")
        sys.exit(1)

    tokens = response.json()
    obo_access_token = tokens.get("access_token")

    if not obo_access_token:
        print("❌ No OBO access token received")
        print(f"Response: {json.dumps(tokens, indent=2)}")
        sys.exit(1)

    print("✅ Successfully obtained on-behalf-of token")
    print(f"\n📋 OBO Token Payload:")
    print(decode_jwt_payload(obo_access_token))

    return obo_access_token


def main():
    """Main function"""
    print("🚀 OAuth2 Flow Test Script")
    print("=" * 50)

    # Check environment variables
    check_environment_variables()

    try:
        # Step 1: Get user token
        user_token = get_user_token()

        # Step 2: Get on-behalf-of token
        obo_token = get_obo_token(user_token)

        print("\n" + "=" * 50)
        print("✅ OAuth2 Flow Completed Successfully!")
        print("=" * 50)

        print(f"\n📄 User Access Token:")
        print(f"{user_token[:50]}...")

        print(f"\n📄 OBO Access Token:")
        print(f"{obo_token[:50]}...")

        print(f"\n💾 Full tokens saved to clipboard-friendly format:")
        print(f"USER_TOKEN={user_token}")
        print(f"OBO_TOKEN={obo_token}")

    except KeyboardInterrupt:
        print("\n❌ Process interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
