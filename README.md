# 🫆 Secure Agentic Demo: HCP Vault x Bedrock x Entra ID

A comprehensive demonstration of secure agentic capabilities combining Microsoft Entra ID authentication, AWS Bedrock AI, HCP Vault for credential management, and AWS DocumentDB for data persistence. This solution specifically addresses the **Confused Deputy Problem** in distributed systems through secure token delegation and dynamic credential management.

## 🎯 The Confused Deputy Problem

### **Problem Definition**
In traditional agentic architectures, a backend service (the "deputy") often uses its own elevated privileges to access resources on behalf of users. This creates several critical security risks:

- **Privilege Escalation**: Users can access data beyond their authorization level
- **Blast Radius**: Compromise of the deputy service exposes all data
- **Audit Gaps**: Difficult to trace actions back to the actual user
- **Policy Drift**: Static permissions become stale and overprivileged

### **Vulnerable Flow Example**
```
User → Agent API → Tool (uses admin DB creds) → Database
                    ↑
        privileged permissions
```

### **Our Secure Solution**
```
User → UI (JWT) → Agent (on-behalf-of JWT) → MCP (Vault auth) → DB (dynamic creds)
  ↑      ↑              ↑                      ↑                    ↑
Identity  Validation    Delegation           Policy Enforcement   Least Privilege
```

### **Security Patterns Implemented**

#### 1. **Token Delegation Pattern**
Instead of using service accounts, each request carries the user's identity through the entire call chain:
- **Frontend**: User JWT from Entra ID
- **Agent API**: On-behalf-of JWT (delegated)
- **MCP Server**: Validated and mapped to Vault policies

#### 2. **Dynamic Secret Pattern**
Database credentials are:
- **Short-lived** (typically 1-24 hours)
- **User/group-specific** (based on Entra ID groups)
- **Just-in-time** (generated when needed)
- **Automatically rotated** (by Vault)

#### 3. **Policy as Code Pattern**
```hcl
# Example Vault Policy for ReadOnly group
path "database/creds/readonly-role" {
  capabilities = ["read"]
}

path "database/static-creds/readonly-*" {
  capabilities = ["read"]
}
```

#### 4. **Zero Trust Validation**
Every component validates incoming tokens:
- JWT signature verification
- Token expiry checks
- Audience validation
- Issuer verification
- Group claim extraction

## 🔄 Identity Propagation vs Service Accounts

### **Traditional Service Account Approach (❌ Vulnerable)**

In conventional architectures, services use their own elevated credentials to access resources:

```python
# ❌ Traditional approach - Service account
class ProductService:
    def __init__(self):
        # Service uses its own elevated credentials
        self.db_client = MongoClient("mongodb://service-account:admin-password@db:27017")
    
    def get_products(self, user_request):
        # Service acts with its own privileges, not user's
        return self.db_client.products.find()  # Admin access for all users!
```

**Problems with Service Accounts:**
- **Privilege Escalation**: Users get admin-level access through the service
- **No User Context**: Database doesn't know which user made the request
- **Audit Gaps**: All actions appear to come from the service account
- **Blast Radius**: Compromise of service account exposes all data

### **Our Identity Propagation Approach (✅ Secure)**

Instead of service accounts, we propagate the user's identity through every service:

```python
# ✅ Our approach - Identity propagation
class ProductService:
    def __init__(self):
        self.vault_client = VaultClient()
    
    def get_products(self, user_jwt):
        # 1. Extract user identity from JWT
        user_info = self.validate_jwt(user_jwt)
        
        # 2. Get user-specific database credentials from Vault
        db_creds = self.vault_client.get_user_credentials(user_jwt)
        
        # 3. Connect to database with user's credentials
        db_client = MongoClient(f"mongodb://{db_creds.username}:{db_creds.password}@db:27017")
        
        # 4. Database knows exactly which user is making the request
        return db_client.products.find({"user_id": user_info.sub})
```

### **Identity Flow Through the System**

#### **Step 1: User Authentication**
```python
# products-web/app.py
def authenticate_user():
    # User logs in with Microsoft Entra ID
    user_jwt = get_oauth_token()  # Contains user identity
    
    # Store user JWT in session
    st.session_state.user_jwt = user_jwt
    return user_jwt
```

#### **Step 2: Agent Request with User Identity**
```python
# products-web/app.py
def call_agent(user_prompt):
    user_jwt = st.session_state.user_jwt
    
    # Send user JWT to agent (not service account token)
    response = requests.post(
        "http://products-agent:8001/agent/invoke",
        headers={"Authorization": f"Bearer {user_jwt}"},  # User's JWT
        json={"prompt": user_prompt}
    )
    return response.json()
```

#### **Step 3: Agent Delegates User Identity**
```python
# products-agent/auth/entra_token_service.py
class EntraTokenService:
    def exchange_token(self, user_jwt):
        # Exchange user JWT for agent-scoped JWT (On-Behalf-Of flow)
        # The agent JWT still contains the original user's identity
        agent_jwt = self.obo_exchange(user_jwt)
        
        # Agent JWT contains:
        # - Original user ID (oid claim)
        # - Agent permissions (scp claim)
        # - User's groups (groups claim)
        return agent_jwt
```

#### **Step 4: MCP Server Uses User Identity for Database Access**
```python
# products-mcp/vault_client.py
class VaultClient:
    def get_mongodb_credentials(self, agent_jwt):
        # 1. Authenticate with Vault using agent JWT (which contains user identity)
        vault_token = self.vault.auth.jwt(agent_jwt)
        
        # 2. Extract user information from JWT
        user_info = self.decode_jwt(agent_jwt)
        user_groups = user_info.get("groups", [])
        
        # 3. Generate user-specific database credentials based on user's groups
        if "Products.ReadWrite" in user_groups:
            role = "readwrite-role"
        elif "Products.ReadOnly" in user_groups:
            role = "readonly-role"
        else:
            raise PermissionError("User has no product access")
        
        # 4. Get dynamic credentials for this specific user
        creds = self.vault.read(f"database/creds/{role}")
        
        # 5. Return user-specific credentials
        return {
            "username": creds["username"],  # e.g., "v-token-readonly-user123-abc"
            "password": creds["password"],  # Unique password for this user
            "ttl": creds["lease_duration"]  # Short-lived (1 hour)
        }
```

#### **Step 5: Database Operations with User Context**
```python
# products-mcp/db_utils.py
class DatabaseManager:
    def get_mongo_client(self, user_jwt):
        # Get user-specific credentials
        creds = self.vault_client.get_mongodb_credentials(user_jwt)
        
        # Connect with user's credentials
        client = MongoClient(
            host=self.config.db_host,
            port=self.config.db_port,
            username=creds["username"],
            password=creds["password"]
        )
        
        # Database now knows exactly which user is connected
        return client
```

### **Identity Claims Throughout the Chain**

#### **User JWT Claims**
```json
{
  "sub": "user-12345",
  "oid": "user-12345",
  "aud": "api://docloudright.onmicrosoft.com/products-web",
  "scp": "openid profile email",
  "groups": ["Products.ReadWrite", "Users.Manage"],
  "name": "John Doe",
  "email": "john.doe@company.com"
}
```

#### **Agent JWT Claims (After OBO Exchange)**
```json
{
  "sub": "agent-service",
  "oid": "user-12345",  // Original user ID preserved!
  "aud": "api://docloudright.onmicrosoft.com/products-agent",
  "scp": "api://docloudright.onmicrosoft.com/products-mcp/Products.Read",
  "groups": ["Products.ReadWrite", "Users.Manage"],  // User's groups preserved!
  "name": "John Doe",  // User's name preserved!
  "email": "john.doe@company.com"  // User's email preserved!
}
```

#### **Vault Policy Based on User Identity**
```hcl
# Vault policy that uses user's group membership
path "database/creds/readwrite-role" {
  capabilities = ["read"]
  required_parameters = ["groups"]
  allowed_parameters = {
    "groups" = ["Products.ReadWrite"]  // Only users with this group
  }
}

# Policy generates user-specific database credentials
# Username: v-token-readwrite-user12345-abc123
# Password: A1b2C3d4E5f6... (unique per user)
```

### **Benefits of Identity Propagation**

#### **1. Complete Audit Trail**
```python
# Every database operation is traceable to a specific user
db.logs.insert_one({
    "operation": "products.find",
    "user_id": "user-12345",
    "user_name": "John Doe",
    "user_email": "john.doe@company.com",
    "timestamp": "2024-01-15T10:30:00Z",
    "ip_address": "192.168.1.100"
})
```

#### **2. Granular Access Control**
```python
# Users only see data they're authorized for
def get_products(user_jwt):
    user_info = validate_jwt(user_jwt)
    
    if "Products.ReadWrite" in user_info.groups:
        # ReadWrite users see all products
        return db.products.find()
    elif "Products.ReadOnly" in user_info.groups:
        # ReadOnly users see only published products
        return db.products.find({"status": "published"})
    else:
        # No access
        raise PermissionError("No product access")
```

#### **3. Dynamic Credential Generation**
```python
# Each user gets unique database credentials
def generate_user_credentials(user_jwt):
    user_info = validate_jwt(user_jwt)
    
    # Credentials are user-specific and short-lived
    return {
        "username": f"v-token-{user_info.role}-{user_info.sub}-{random_id}",
        "password": generate_secure_password(),  # Unique per user
        "ttl": 3600,  # 1 hour expiration
        "permissions": get_user_permissions(user_info.groups)
    }
```

#### **4. Zero Trust Validation**
```python
# Every service validates the user's identity
def validate_user_identity(jwt_token):
    # 1. Verify JWT signature
    payload = jwt.decode(jwt_token, verify=True)
    
    # 2. Check token expiry
    if payload["exp"] < time.time():
        raise TokenExpiredError()
    
    # 3. Validate audience
    if payload["aud"] != expected_audience:
        raise InvalidAudienceError()
    
    # 4. Extract user information
    return {
        "user_id": payload["sub"],
        "groups": payload.get("groups", []),
        "permissions": map_groups_to_permissions(payload.get("groups", []))
    }
```

### **Comparison: Service Account vs Identity Propagation**

| Aspect | Service Account (❌) | Identity Propagation (✅) |
|--------|---------------------|---------------------------|
| **Database Access** | Same admin credentials for all users | Unique credentials per user |
| **Audit Trail** | All actions from service account | Every action traceable to user |
| **Access Control** | Binary (all or nothing) | Granular based on user groups |
| **Credential Rotation** | Manual, infrequent | Automatic, per-user |
| **Blast Radius** | High (admin access) | Low (user-specific access) |
| **Compliance** | Difficult to prove user access | Complete user activity logs |
| **Security** | Privilege escalation risk | Least privilege principle |

### **Real-World Example**

**Scenario**: User "Alice" (ReadOnly) and User "Bob" (ReadWrite) both request product data.

#### **With Service Accounts (❌)**
```python
# Both users get admin access through service account
alice_request → service_account → admin_db_creds → full_access
bob_request   → service_account → admin_db_creds → full_access

# Database logs show:
# "service_account accessed products table" (no user context)
```

#### **With Identity Propagation (✅)**
```python
# Each user gets appropriate access based on their identity
alice_request → alice_jwt → readonly_db_creds → limited_access
bob_request   → bob_jwt   → readwrite_db_creds → full_access

# Database logs show:
# "alice@company.com (readonly-user123-abc) accessed products table"
# "bob@company.com (readwrite-user456-def) accessed products table"
```

This identity propagation approach ensures that **every action in the system is traceable to a specific user** and that **users only get the permissions they're authorized for**, completely eliminating the Confused Deputy Problem.

## 🔍 User Session Traceability and Validation

### **Complete Audit Trail: From Authentication to Database**

This section demonstrates how to validate and trace user sessions through the entire authentication flow and database operations, showing the complete audit trail from user login to database access.

### **Step 1: User Authentication Validation**

#### **Frontend Authentication Logging**
```python
# products-web/app.py
import logging
from datetime import datetime

def authenticate_user():
    """Authenticate user and log session details"""
    try:
        # Get OAuth token from Microsoft Entra ID
        user_jwt = get_oauth_token()
        
        # Decode JWT to extract user information
        user_info = decode_jwt(user_jwt)
        
        # Log user authentication
        logging.info({
            "event": "user_authenticated",
            "user_id": user_info["sub"],
            "user_name": user_info.get("name"),
            "user_email": user_info.get("email"),
            "user_groups": user_info.get("groups", []),
            "session_id": st.session_state.get("session_id"),
            "timestamp": datetime.utcnow().isoformat(),
            "ip_address": get_client_ip(),
            "user_agent": st.session_state.get("user_agent")
        })
        
        # Store in session for traceability
        st.session_state.user_jwt = user_jwt
        st.session_state.user_info = user_info
        st.session_state.session_id = generate_session_id()
        
        return user_jwt
        
    except Exception as e:
        logging.error({
            "event": "authentication_failed",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat(),
            "ip_address": get_client_ip()
        })
        raise
```

#### **Session Tracking**
```python
# products-web/app.py
def track_user_session():
    """Track user session for audit purposes"""
    session_data = {
        "session_id": st.session_state.session_id,
        "user_id": st.session_state.user_info["sub"],
        "user_name": st.session_state.user_info.get("name"),
        "user_email": st.session_state.user_info.get("email"),
        "login_time": datetime.utcnow().isoformat(),
        "last_activity": datetime.utcnow().isoformat(),
        "ip_address": get_client_ip(),
        "user_agent": st.session_state.get("user_agent")
    }
    
    # Store session data for audit trail
    store_session_data(session_data)
    
    return session_data
```

### **Step 2: Agent Request Validation and Logging**

#### **Agent Request Logging**
```python
# products-agent/main.py
import logging
from datetime import datetime

@app.post("/agent/invoke")
async def invoke_agent(request: AgentRequest, authorization: str = Header(None)):
    """Process agent request with complete audit logging"""
    
    # Extract and validate user JWT
    user_jwt = extract_jwt_from_header(authorization)
    user_info = validate_jwt(user_jwt)
    
    # Log agent request
    request_log = {
        "event": "agent_request_received",
        "request_id": generate_request_id(),
        "user_id": user_info["sub"],
        "user_name": user_info.get("name"),
        "user_email": user_info.get("email"),
        "user_groups": user_info.get("groups", []),
        "prompt": request.prompt,
        "timestamp": datetime.utcnow().isoformat(),
        "ip_address": get_client_ip(),
        "session_id": extract_session_id_from_jwt(user_jwt)
    }
    
    logging.info(request_log)
    
    try:
        # Exchange user JWT for agent JWT (OBO flow)
        agent_jwt = await token_service.exchange_token(user_jwt)
        
        # Log OBO exchange
        logging.info({
            "event": "obo_token_exchange",
            "request_id": request_log["request_id"],
            "user_id": user_info["sub"],
            "agent_jwt_sub": decode_jwt(agent_jwt)["sub"],
            "agent_jwt_oid": decode_jwt(agent_jwt)["oid"],  # Original user ID
            "timestamp": datetime.utcnow().isoformat()
        })
        
        # Process request with Bedrock
        response = await process_with_bedrock(request.prompt, agent_jwt)
        
        # Log successful response
        logging.info({
            "event": "agent_response_sent",
            "request_id": request_log["request_id"],
            "user_id": user_info["sub"],
            "response_length": len(response),
            "timestamp": datetime.utcnow().isoformat()
        })
        
        return {"response": response, "request_id": request_log["request_id"]}
        
    except Exception as e:
        # Log error with full context
        logging.error({
            "event": "agent_request_failed",
            "request_id": request_log["request_id"],
            "user_id": user_info["sub"],
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        })
        raise
```

### **Step 3: MCP Server Database Access Validation**

#### **MCP Server Request Logging**
```python
# products-mcp/server.py
import logging
from datetime import datetime

@mcp.tool()
async def list_products(user_jwt: str) -> str:
    """List products with complete audit trail"""
    
    # Extract user information from JWT
    user_info = validate_jwt(user_jwt)
    
    # Generate request ID for traceability
    request_id = generate_request_id()
    
    # Log MCP request
    mcp_log = {
        "event": "mcp_request_received",
        "request_id": request_id,
        "tool": "list_products",
        "user_id": user_info["sub"],
        "user_name": user_info.get("name"),
        "user_email": user_info.get("email"),
        "user_groups": user_info.get("groups", []),
        "timestamp": datetime.utcnow().isoformat()
    }
    
    logging.info(mcp_log)
    
    try:
        # Get user-specific database credentials from Vault
        vault_creds = await vault_client.get_mongodb_credentials(user_jwt)
        
        # Log Vault credential generation
        logging.info({
            "event": "vault_credentials_generated",
            "request_id": request_id,
            "user_id": user_info["sub"],
            "vault_username": vault_creds["username"],
            "vault_ttl": vault_creds["ttl"],
            "timestamp": datetime.utcnow().isoformat()
        })
        
        # Connect to database with user's credentials
        db_client = await db_manager.get_mongo_client(user_jwt)
        
        # Log database connection
        logging.info({
            "event": "database_connected",
            "request_id": request_id,
            "user_id": user_info["sub"],
            "db_username": vault_creds["username"],
            "timestamp": datetime.utcnow().isoformat()
        })
        
        # Execute database query
        products = await db_client.products.find().to_list(length=None)
        
        # Log database query execution
        logging.info({
            "event": "database_query_executed",
            "request_id": request_id,
            "user_id": user_info["sub"],
            "query": "products.find()",
            "result_count": len(products),
            "timestamp": datetime.utcnow().isoformat()
        })
        
        return format_products_response(products)
        
    except Exception as e:
        # Log error with full context
        logging.error({
            "event": "mcp_request_failed",
            "request_id": request_id,
            "user_id": user_info["sub"],
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        })
        raise
```

### **Step 4: Vault Credential Generation and Mapping**

#### **Vault Client with Detailed Logging**
```python
# products-mcp/vault_client.py
import logging
from datetime import datetime

class VaultClient:
    async def get_mongodb_credentials(self, user_jwt: str) -> dict:
        """Get user-specific database credentials with complete audit trail"""
        
        # Extract user information
        user_info = self.decode_jwt(user_jwt)
        user_groups = user_info.get("groups", [])
        
        # Log Vault authentication attempt
        vault_log = {
            "event": "vault_auth_attempt",
            "user_id": user_info["sub"],
            "user_name": user_info.get("name"),
            "user_email": user_info.get("email"),
            "user_groups": user_groups,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        logging.info(vault_log)
        
        try:
            # Authenticate with Vault using user JWT
            vault_token = await self.vault.auth.jwt(user_jwt)
            
            # Log successful Vault authentication
            logging.info({
                "event": "vault_auth_success",
                "user_id": user_info["sub"],
                "vault_token_ttl": vault_token.get("lease_duration"),
                "timestamp": datetime.utcnow().isoformat()
            })
            
            # Determine user role based on groups
            if "Products.ReadWrite" in user_groups:
                role = "readwrite-role"
                permissions = ["read", "create", "update", "delete"]
            elif "Products.ReadOnly" in user_groups:
                role = "readonly-role"
                permissions = ["read"]
            else:
                raise PermissionError("User has no product access")
            
            # Log role determination
            logging.info({
                "event": "user_role_determined",
                "user_id": user_info["sub"],
                "role": role,
                "permissions": permissions,
                "timestamp": datetime.utcnow().isoformat()
            })
            
            # Generate dynamic credentials
            creds_path = f"database/creds/{role}"
            creds_response = await self.vault.read(creds_path)
            
            # Log credential generation
            logging.info({
                "event": "dynamic_credentials_generated",
                "user_id": user_info["sub"],
                "role": role,
                "vault_username": creds_response["username"],
                "vault_ttl": creds_response["lease_duration"],
                "timestamp": datetime.utcnow().isoformat()
            })
            
            return {
                "username": creds_response["username"],
                "password": creds_response["password"],
                "ttl": creds_response["lease_duration"],
                "role": role,
                "permissions": permissions
            }
            
        except Exception as e:
            # Log Vault error
            logging.error({
                "event": "vault_auth_failed",
                "user_id": user_info["sub"],
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            })
            raise
```

### **Step 5: Database Operation Audit Trail**

#### **Database Manager with Session Tracking**
```python
# products-mcp/db_utils.py
import logging
from datetime import datetime

class DatabaseManager:
    async def get_mongo_client(self, user_jwt: str) -> MongoClient:
        """Get database client with user-specific credentials and audit trail"""
        
        # Get user information
        user_info = self.decode_jwt(user_jwt)
        
        # Get Vault credentials
        vault_creds = await self.vault_client.get_mongodb_credentials(user_jwt)
        
        # Log database connection attempt
        logging.info({
            "event": "database_connection_attempt",
            "user_id": user_info["sub"],
            "user_name": user_info.get("name"),
            "user_email": user_info.get("email"),
            "db_username": vault_creds["username"],
            "db_role": vault_creds["role"],
            "timestamp": datetime.utcnow().isoformat()
        })
        
        try:
            # Create database client with user credentials
            client = MongoClient(
                host=self.config.db_host,
                port=self.config.db_port,
                username=vault_creds["username"],
                password=vault_creds["password"],
                authSource="admin"
            )
            
            # Test connection
            await client.admin.command('ping')
            
            # Log successful connection
            logging.info({
                "event": "database_connected_successfully",
                "user_id": user_info["sub"],
                "db_username": vault_creds["username"],
                "db_role": vault_creds["role"],
                "timestamp": datetime.utcnow().isoformat()
            })
            
            # Store connection info for audit
            self.connection_audit[user_info["sub"]] = {
                "db_username": vault_creds["username"],
                "role": vault_creds["role"],
                "connected_at": datetime.utcnow().isoformat(),
                "ttl": vault_creds["ttl"]
            }
            
            return client
            
        except Exception as e:
            # Log connection failure
            logging.error({
                "event": "database_connection_failed",
                "user_id": user_info["sub"],
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            })
            raise
```

### **Step 6: Complete Audit Trail Validation**

#### **Audit Trail Query Examples**
```python
# Audit trail validation functions

def get_user_session_trail(user_id: str, session_id: str = None):
    """Get complete audit trail for a user session"""
    
    # Query all logs for user
    query = {"user_id": user_id}
    if session_id:
        query["session_id"] = session_id
    
    # Get all events for user
    events = db.audit_logs.find(query).sort("timestamp", 1)
    
    return {
        "user_id": user_id,
        "session_id": session_id,
        "events": list(events),
        "total_events": events.count()
    }

def get_database_access_trail(user_id: str):
    """Get database access trail for a user"""
    
    events = db.audit_logs.find({
        "user_id": user_id,
        "event": {"$in": [
            "database_connected",
            "database_query_executed",
            "vault_credentials_generated"
        ]}
    }).sort("timestamp", 1)
    
    return {
        "user_id": user_id,
        "database_events": list(events),
        "total_db_events": events.count()
    }

def get_vault_credential_trail(user_id: str):
    """Get Vault credential generation trail for a user"""
    
    events = db.audit_logs.find({
        "user_id": user_id,
        "event": {"$in": [
            "vault_auth_attempt",
            "vault_auth_success",
            "dynamic_credentials_generated"
        ]}
    }).sort("timestamp", 1)
    
    return {
        "user_id": user_id,
        "vault_events": list(events),
        "total_vault_events": events.count()
    }
```

### **Step 7: Real-World Audit Trail Example**

#### **Complete User Session Trace**
```json
{
  "user_session": {
    "user_id": "user-12345",
    "user_name": "John Doe",
    "user_email": "john.doe@company.com",
    "session_id": "sess-abc123",
    "login_time": "2024-01-15T10:30:00Z",
    "total_events": 8
  },
  "audit_trail": [
    {
      "event": "user_authenticated",
      "timestamp": "2024-01-15T10:30:00Z",
      "user_id": "user-12345",
      "user_groups": ["Products.ReadWrite"],
      "ip_address": "192.168.1.100"
    },
    {
      "event": "agent_request_received",
      "timestamp": "2024-01-15T10:30:15Z",
      "request_id": "req-xyz789",
      "user_id": "user-12345",
      "prompt": "list all products"
    },
    {
      "event": "obo_token_exchange",
      "timestamp": "2024-01-15T10:30:16Z",
      "request_id": "req-xyz789",
      "user_id": "user-12345",
      "agent_jwt_oid": "user-12345"
    },
    {
      "event": "mcp_request_received",
      "timestamp": "2024-01-15T10:30:17Z",
      "request_id": "req-xyz789",
      "user_id": "user-12345",
      "tool": "list_products"
    },
    {
      "event": "vault_auth_attempt",
      "timestamp": "2024-01-15T10:30:18Z",
      "user_id": "user-12345",
      "user_groups": ["Products.ReadWrite"]
    },
    {
      "event": "vault_auth_success",
      "timestamp": "2024-01-15T10:30:19Z",
      "user_id": "user-12345",
      "vault_token_ttl": 3600
    },
    {
      "event": "dynamic_credentials_generated",
      "timestamp": "2024-01-15T10:30:20Z",
      "user_id": "user-12345",
      "role": "readwrite-role",
      "vault_username": "v-token-readwrite-user12345-abc123"
    },
    {
      "event": "database_query_executed",
      "timestamp": "2024-01-15T10:30:21Z",
      "request_id": "req-xyz789",
      "user_id": "user-12345",
      "query": "products.find()",
      "result_count": 5
    }
  ]
}
```

### **Step 8: Validation Commands**

#### **Command-Line Validation Tools**
```bash
# Check user session trail
curl -X GET "http://localhost:8000/audit/user/user-12345/session/sess-abc123" \
     -H "Authorization: Bearer $ADMIN_JWT"

# Check database access for user
curl -X GET "http://localhost:8000/audit/user/user-12345/database" \
     -H "Authorization: Bearer $ADMIN_JWT"

# Check Vault credential generation
curl -X GET "http://localhost:8000/audit/user/user-12345/vault" \
     -H "Authorization: Bearer $ADMIN_JWT"

# Check all events for a specific request
curl -X GET "http://localhost:8000/audit/request/req-xyz789" \
     -H "Authorization: Bearer $ADMIN_JWT"
```

#### **Database Query Validation**
```python
# Direct database audit queries
def validate_user_traceability(user_id: str):
    """Validate complete user traceability"""
    
    # Check authentication events
    auth_events = db.audit_logs.find({
        "user_id": user_id,
        "event": "user_authenticated"
    })
    
    # Check agent requests
    agent_events = db.audit_logs.find({
        "user_id": user_id,
        "event": "agent_request_received"
    })
    
    # Check database access
    db_events = db.audit_logs.find({
        "user_id": user_id,
        "event": "database_query_executed"
    })
    
    # Check Vault credential generation
    vault_events = db.audit_logs.find({
        "user_id": user_id,
        "event": "dynamic_credentials_generated"
    })
    
    return {
        "user_id": user_id,
        "authentication_events": list(auth_events),
        "agent_requests": list(agent_events),
        "database_access": list(db_events),
        "vault_credentials": list(vault_events),
        "traceability_complete": len(list(auth_events)) > 0 and len(list(db_events)) > 0
    }
```

### **Benefits of Complete Traceability**

#### **1. Compliance and Auditing**
- **Complete Audit Trail**: Every action traceable to specific user
- **Regulatory Compliance**: Meets SOX, GDPR, HIPAA requirements
- **Forensic Analysis**: Detailed logs for security investigations

#### **2. Security Monitoring**
- **Anomaly Detection**: Unusual user behavior patterns
- **Access Monitoring**: Real-time monitoring of database access
- **Credential Tracking**: Monitor Vault credential generation and usage

#### **3. Operational Insights**
- **User Behavior**: Understanding how users interact with the system
- **Performance Monitoring**: Track request processing times
- **Error Analysis**: Detailed error logs with user context

This comprehensive audit trail ensures that **every user action is completely traceable** from authentication through database access, providing complete visibility into user behavior and system security.

## 🏗️ Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐            ┌─────────────────┐
│                 │     │                 │            │                 │
│  products-web   │────▶│ products-agent  │──────────▶ │  products-mcp   │
│   (Frontend)    │     │  (Agent API)    │            │  (MCP Server)   │
│  Streamlit UI   │     │  FastAPI + AI   │            │ Data Access     │
└─────────────────┘     └─────────────────┘            └─────────────────┘
         │                   │          │                   │
         │ OAuth2/JWT        │ OBO      │ LLM               │ Dynamic DB Creds
         │                   │          │                   │
         ▼                   ▼          ▼                   ▼
┌─────────────────┐   ┌────────────┐  ┌────────────┐   ┌─────────────────┐
│ Microsoft       │   │ Microsoft  │  │ AWS        │   │   HCP Vault     │
│ Entra ID        │   │ Entra ID   │  │ Bedrock    │   │ + DocumentDB    │
└─────────────────┘   └────────────┘   └────────────┘   └─────────────────┘
```

## 🔐 Why HCP Vault?

### **Traditional Database Access Problems**
```python
# ❌ Traditional approach - Static credentials
DATABASE_URL = "mongodb://admin:password123@db.example.com:27017/products"
# Problems:
# - Same credentials for all users
# - Credentials never rotate
# - Admin-level access for all operations
# - No audit trail of who accessed what
```

### **HCP Vault Solution**
```python
# ✅ Vault approach - Dynamic credentials
def get_database_credentials(user_jwt):
    # 1. Validate user JWT
    user_info = validate_jwt(user_jwt)
    
    # 2. Authenticate with Vault using user identity
    vault_token = vault.auth.jwt(user_jwt)
    
    # 3. Generate user-specific database credentials
    creds = vault.read(f"database/creds/{user_info.role}")
    
    # 4. Return short-lived, scoped credentials
    return {
        "username": creds["username"],  # e.g., "v-token-readonly-abc123"
        "password": creds["password"],  # e.g., "A1b2C3d4E5f6..."
        "ttl": creds["lease_duration"]  # e.g., 3600 seconds
    }
```

### **Vault Benefits**
1. **Dynamic Credentials**: Each user gets unique DB credentials
2. **Automatic Rotation**: Credentials expire and rotate automatically
3. **Least Privilege**: Users only get permissions they need
4. **Audit Trail**: Every credential generation is logged
5. **Policy Enforcement**: Centralized access control
6. **Zero Static Secrets**: No hardcoded database passwords

## 🧩 Component Overview

### 1. **products-web** - Frontend Interface
- **Technology**: Streamlit web application
- **Authentication**: Microsoft Entra ID OAuth2/JWT
- **Purpose**: User interface for interacting with the AI agent
- **Port**: 8501
- **Security**: Validates user JWT, exchanges for agent token

### 2. **products-agent** - AI Agent API
- **Technology**: FastAPI with AWS Bedrock Nova Pro
- **Authentication**: On-Behalf-Of (OBO) token exchange
- **Purpose**: AI-powered agent that processes user requests
- **Port**: 8001
- **Security**: Delegates user identity to MCP server

### 3. **products-mcp** - Data Access Layer
- **Technology**: Model Context Protocol (MCP) server
- **Authentication**: JWT validation with dynamic credentials
- **Purpose**: Secure database operations with HCP Vault integration
- **Port**: 8000
- **Security**: Generates dynamic DB credentials per user

## 🔄 Authentication Flow

### **Step-by-Step Authentication Process**

#### 1. **User Login (Frontend)**
```mermaid
sequenceDiagram
    participant U as User
    participant W as ProductsWeb
    participant E as Entra ID
    
    U->>W: Click "Login with Microsoft"
    W->>E: Redirect to OAuth2 login
    E->>U: Show login form
    U->>E: Enter credentials
    E->>W: Return authorization code
    W->>E: Exchange code for JWT
    E->>W: Return user JWT
    W->>W: Store JWT in session
```

#### 2. **Agent Request (OBO Flow)**
```mermaid
sequenceDiagram
    participant W as ProductsWeb
    participant A as ProductsAgent
    participant E as Entra ID
    
    W->>A: POST /agent/invoke with user JWT
    A->>E: OBO token exchange request
    Note over A,E: client_credentials + user JWT
    E->>A: Return agent-scoped JWT
    A->>A: Validate agent JWT
    A->>A: Process request with Bedrock
```

#### 3. **Database Access (Dynamic Credentials)**
```mermaid
sequenceDiagram
    participant A as ProductsAgent
    participant M as ProductsMCP
    participant V as HCP Vault
    participant D as DocumentDB
    
    A->>M: POST /mcp with agent JWT
    M->>V: Authenticate with JWT
    V->>M: Return Vault token
    M->>V: Request database credentials
    V->>M: Return dynamic DB credentials
    M->>D: Connect with dynamic credentials
    D->>M: Return query results
    M->>A: Return data
```

### **Token Scopes and Permissions**

#### **User JWT Scopes**
```json
{
  "aud": "api://docloudright.onmicrosoft.com/products-web",
  "scp": "openid profile email",
  "groups": ["Products.ReadOnly", "Products.ReadWrite"],
  "sub": "user-12345"
}
```

#### **Agent JWT Scopes**
```json
{
  "aud": "api://docloudright.onmicrosoft.com/products-agent",
  "scp": "api://docloudright.onmicrosoft.com/products-mcp/Products.Read",
  "oid": "user-12345",
  "sub": "agent-service"
}
```

#### **Vault Policy Mapping**
```hcl
# ReadOnly users get limited database access
path "database/creds/readonly-role" {
  capabilities = ["read"]
  required_parameters = ["groups"]
  allowed_parameters = {
    "groups" = ["Products.ReadOnly"]
  }
}

# ReadWrite users get full database access
path "database/creds/readwrite-role" {
  capabilities = ["read", "create", "update", "delete"]
  required_parameters = ["groups"]
  allowed_parameters = {
    "groups" = ["Products.ReadWrite"]
  }
}
```

## 🚀 Deployment Guide

### **Prerequisites**
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Docker and Docker Compose installed
- Access to Microsoft Entra ID tenant
- HCP Vault account (free tier available)

### **Step 1: Infrastructure Deployment**

#### **Configure Terraform Variables**
```bash
# Copy and edit the example file
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit with your values
nano terraform/terraform.tfvars
```

**Required Variables:**
```hcl
# AWS Configuration
aws_region = "eu-central-1"
aws_account_id = "YOUR_AWS_ACCOUNT_ID"

# Microsoft Entra ID Configuration
tenant_id = "YOUR_TENANT_ID"
ad_user_password = "YOUR_AD_USER_PASSWORD"

# DocumentDB Configuration
docdb_master_username = "YOUR_DB_USERNAME"
docdb_master_password = "YOUR_DB_PASSWORD"

# HCP Vault Configuration
hcp_vault_tier = "dev"  # or "standard" for production
```

#### **Deploy Infrastructure**
```bash
cd terraform

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Deploy infrastructure
terraform apply
```

**What Gets Created:**
- VPC with public/private subnets
- Bastion host with Application Load Balancer
- DocumentDB cluster with security groups
- HCP Vault cluster
- Azure AD application registrations
- ECR repositories for container images

### **Step 2: Application Deployment**

#### **Build and Push Container Images**
```bash
# Build and push all images to ECR
./deploy-ecr.sh
```

#### **Deploy to Bastion Host**
```bash
# Get bastion host IP
BASTION_IP=$(terraform output -raw bastion_public_ip)

# Copy deployment files
scp -i terraform/ai-l0q-bastion-key.pem -r docker-compose/ ubuntu@$BASTION_IP:/home/ubuntu/
scp -i terraform/ai-l0q-bastion-key.pem docker-compose-unified.yml ubuntu@$BASTION_IP:/home/ubuntu/docker-compose/

# SSH into bastion host
ssh -i terraform/ai-l0q-bastion-key.pem ubuntu@$BASTION_IP

# On bastion host, start services
cd /home/ubuntu/docker-compose
docker compose -f docker-compose-unified.yml up -d
```

### **Step 3: Post-Deployment Configuration**

#### **Run Post-Deployment Fixes**
```bash
# On bastion host
./post-deploy-fix.sh
```

#### **Configure Automated Secret Management**
```bash
# Auto-configure scripts with Terraform outputs
./scripts/auto-configure.sh

# Optional: Convert docker-compose files to use variables
./scripts/update-docker-compose-variables.sh
```

### **Step 4: Access Application**
```bash
# Get application URL
terraform output alb_https_url

# Open in browser
open https://$(terraform output -raw alb_https_url)
```

## 🔧 Automated Secret Management

The solution includes automated scripts to handle Azure AD client secret updates that occur during Terraform applies. All scripts now use **centralized configuration** with variables instead of hardcoded values.

### **Why Automated Secret Management?**

**Problem**: Azure AD application passwords are regenerated every time you run `terraform apply`, but Docker containers continue using the old client secrets, causing authentication failures.

**Solution**: Automated scripts that detect secret mismatches and update containers automatically.

### **Initial Setup (One-time)**
```bash
# Auto-configure scripts with Terraform outputs
./scripts/auto-configure.sh

# Optional: Convert docker-compose files to use variables
./scripts/update-docker-compose-variables.sh
```

### **Available Scripts**

#### `update-secrets.sh` - Main Update Script
```bash
# Fix authentication issues immediately
./scripts/update-secrets.sh
```

#### `check-auth-health.sh` - Health Monitor
```bash
# Check system health and fix issues if found
./scripts/check-auth-health.sh
```

#### `terraform-post-apply.sh` - Terraform Hook
```bash
# Run after terraform apply
terraform apply && ./scripts/terraform-post-apply.sh
```

### **Automated Workflow Options**

#### Option 1: Manual Monitoring
```bash
# Check every 5 minutes
while true; do
    ./scripts/check-auth-health.sh
    sleep 300
done
```

#### Option 2: Cron Job
```bash
# Add to crontab for automatic monitoring
*/5 * * * * /path/to/confused-deputy-aws/scripts/check-auth-health.sh
```

#### Option 3: Systemd Service (Recommended for Production)
```bash
# Copy service file
sudo cp scripts/auth-monitor.service /etc/systemd/system/

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable auth-monitor.service
sudo systemctl start auth-monitor.service

# Check status
systemctl status auth-monitor.service
```

## 📊 What the Scripts Handle

### **Secret Update Process**
1. **Compare Secrets**: Terraform output vs container environment
2. **Detect Mismatches**: Identify outdated client secrets
3. **Update Files**: Modify both `.env` files and `docker-compose.yml` hardcoded values
4. **Recreate Containers**: Complete container recreation (not just restart)
5. **Verify Health**: Confirm services are running and healthy

### **Health Monitoring**
1. **Log Analysis**: Check recent logs for authentication errors
2. **HTTP Health**: Verify service endpoints are responding
3. **Auto-Fix**: Trigger secret updates when issues detected
4. **Reporting**: Provide clear status messages

## 🎯 Services Monitored

- **ProductsAgent** (`${PRODUCTS_AGENT_CLIENT_ID}`)
  - Environment: `ENTRA_CLIENT_SECRET`
  - Health: `http://localhost:8001/health`
  - Log Pattern: `invalid_client|AADSTS7000215|Token exchange failed`

- **ProductsWeb** (`${PRODUCTS_WEB_CLIENT_ID}`)
  - Environment: `CLIENT_SECRET`
  - Health: `http://localhost:8501/_stcore/health`
  - Log Pattern: `invalid_client|AADSTS7000215|Authentication failed`

## 🧪 Testing the Application

### **Web Interface Testing**
1. Open the application URL: `https://$(terraform output -raw alb_https_url)`
2. Click "Login with Microsoft" and authenticate with your Entra ID user
3. Once authenticated, try interacting with the AI agent

### **Test Queries**
```
"list all products"
"show me products under $100"
"create a new product called 'Gaming Headset' priced at $199.99"
"search for laptop products"
"update the laptop price to $1199.99"
"delete the gaming headset"
```

### **Expected Results**
You should see responses like:
```
Here is the list of all products:

| ID              | Name               | Price  |
|-----------------|--------------------|--------|
| 68ef3f5e0812023112ce5f47 | Laptop            | 1299.99 |
| 68ef3f5e0812023112ce5f48 | Wireless Mouse   | 29.99  |
| 68ef3f5e0812023112ce5f49 | Mechanical Keyboard | 149.99 |
```

### **API Testing (ProductsAgent)**
You can test the ProductsAgent API directly using `curl` or a tool like Postman/Insomnia.

1. **Get an access token**: Authenticate via the web UI and inspect network requests, or use a tool like MSAL
2. **Invoke agent**:
   ```bash
   curl -X POST "https://$(terraform output -raw alb_https_url)/agent/invoke" \
        -H "Authorization: Bearer <YOUR_ACCESS_TOKEN>" \
        -H "Content-Type: application/json" \
        -d '{ "prompt": "list all products" }'
   ```
3. **Check health**:
   ```bash
   curl https://$(terraform output -raw alb_https_url)/health
   ```

### **API Testing (ProductsMCP)**
The ProductsMCP API is internal and not directly exposed. It's called by the ProductsAgent.

## 🔍 Troubleshooting

### **Check Service Status**
```bash
# SSH into bastion host
ssh -i terraform/ai-l0q-bastion-key.pem ubuntu@$(terraform output -raw bastion_public_ip)

# Check container status
docker ps

# Check service logs
docker logs products-agent --tail=20
docker logs products-mcp --tail=20
docker logs products-web --tail=20
```

### **Manual Verification**
```bash
# Check container secrets
docker exec products-agent env | grep ENTRA_CLIENT_SECRET
docker exec products-web env | grep CLIENT_SECRET

# Check Terraform outputs
terraform output products_agent_client_secret
terraform output products_web_client_secret
```

### **Health Checks**
```bash
# Check service health
curl http://localhost:8001/health
curl http://localhost:8501/_stcore/health
curl http://localhost:8000/mcp
```

### **Common Issues and Solutions**

#### **Authentication Failures**
```bash
# Check for secret mismatches
./scripts/check-auth-health.sh

# Manually update secrets
./scripts/update-secrets.sh
```

#### **Database Connection Issues**
```bash
# Check Vault connectivity
curl -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/sys/health

# Check DocumentDB connectivity
telnet $(terraform output -raw docdb_endpoint) 27017
```

#### **Bedrock API Issues**
```bash
# Check Bedrock permissions
aws bedrock list-foundation-models --region eu-central-1

# Check IAM policy
aws iam get-policy-version --policy-arn $(terraform output -raw bastion_iam_policy_arn) --version-id v1
```

## 📁 Project Structure

```
confused-deputy-aws/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output definitions
│   ├── providers.tf          # Provider configurations
│   ├── export-env.sh         # Environment setup script
│   └── modules/              # Terraform modules
│       ├── aws-networking/   # VPC, subnets, security groups
│       ├── aws-documentdb/   # DocumentDB cluster
│       ├── bastion/          # Bastion host and ALB
│       ├── hcp-vault/        # HCP Vault cluster
│       ├── azure-ad-app/     # Azure AD applications
│       ├── vault-auth/       # Vault authentication setup
│       └── ecr/              # ECR repositories
├── products-web/             # Streamlit frontend
│   ├── app.py               # Main application
│   ├── docker-build.sh      # Build script
│   └── .env.example         # Environment template
├── products-agent/           # FastAPI AI agent
│   ├── main.py              # Main application
│   ├── products_agent.py    # Agent logic
│   ├── auth/                # Authentication modules
│   ├── docker-build.sh      # Build script
│   └── .env.example         # Environment template
├── products-mcp/             # MCP server for data access
│   ├── server.py            # MCP server
│   ├── vault_client.py      # Vault integration
│   ├── db_utils.py          # Database utilities
│   ├── docker-build.sh      # Build script
│   └── .env.example         # Environment template
├── docker-compose/           # Docker Compose configurations
│   ├── docker-compose.yml   # Main compose file
│   ├── products-web/        # Web service config
│   ├── products-agent/      # Agent service config
│   └── products-mcp/        # MCP service config
├── scripts/                  # Automated management scripts
│   ├── update-secrets.sh     # Main secret update script
│   ├── check-auth-health.sh  # Health monitoring script
│   ├── terraform-post-apply.sh # Terraform hook
│   ├── auto-configure.sh    # Auto-configuration script
│   ├── setup.sh             # Setup script
│   └── README.md            # Script documentation
├── docker-compose-unified.yml # Unified compose file
├── deploy-ecr.sh            # ECR deployment script
├── post-deploy-fix.sh       # Post-deployment fixes
├── BEDROCK_CONFIGURATION.md # Bedrock setup guide
└── README.md                # This file
```

## ✅ Benefits

### **Security Benefits**
1. **Zero Static Secrets**: No hardcoded database passwords
2. **Dynamic Credentials**: Each user gets unique, temporary credentials
3. **Least Privilege**: Users only get permissions they need
4. **Audit Trail**: Every action is traceable to a specific user
5. **Automatic Rotation**: Credentials expire and rotate automatically

### **Operational Benefits**
1. **Zero Manual Intervention**: No more manual secret updates
2. **Proactive Monitoring**: Detects issues before they impact users
3. **Automatic Recovery**: Self-healing system that fixes issues automatically
4. **Clear Reporting**: Detailed logs of what was updated and why
5. **Terraform Integration**: Seamless workflow integration
6. **Production Ready**: Robust error handling and verification

### **Developer Benefits**
1. **Clear Architecture**: Well-defined service boundaries
2. **Comprehensive Documentation**: Detailed setup and troubleshooting guides
3. **Automated Testing**: Built-in health checks and monitoring
4. **Easy Deployment**: One-command infrastructure and application deployment
5. **Scalable Design**: Can be extended for additional services and users

## 🎉 Result

**Before**: Manual intervention required every time Terraform regenerates secrets, static database credentials, no audit trail, privilege escalation risks

**After**: Fully automated system that handles secret updates transparently, dynamic user-specific credentials, complete audit trail, zero privilege escalation

The recurring authentication issues are now completely solved with a production-ready automated solution that addresses the Confused Deputy Problem! 🚀

## 📚 Additional Resources

- [Microsoft Entra ID Documentation](https://docs.microsoft.com/en-us/azure/active-directory/)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [HCP Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Model Context Protocol (MCP) Specification](https://modelcontextprotocol.io/)
- [Streamlit Documentation](https://docs.streamlit.io/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

## 🤝 Contributing

This project demonstrates secure agentic architecture patterns. Contributions are welcome for:
- Additional security patterns
- New authentication methods
- Enhanced monitoring capabilities
- Additional service integrations

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.