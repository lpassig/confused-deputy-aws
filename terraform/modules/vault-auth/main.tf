resource "vault_mount" "db" {
  path = "database"
  type = "database"
}

resource "vault_policy" "readonly" {
  name   = "readonly"
  policy = <<EOF
path "database/creds/readonly" {
  capabilities = ["read"]
}
EOF
}

resource "vault_policy" "readwrite" {
  name   = "readwrite"
  policy = <<EOF
path "database/creds/readwrite" {
  capabilities = ["read"]
}
EOF
}

resource "vault_database_secret_backend_connection" "docdb" {
  backend       = vault_mount.db.path
  name          = "docdb"
  allowed_roles = ["readonly,readwrite"]

  mongodb {
    connection_url = "mongodb://{{username}}:{{password}}@${var.docdb_cluster_endpoint}:27017/admin"
    username       = var.docdb_username
    password       = var.docdb_password
  }
}

resource "vault_database_secret_backend_role" "readonly" {
  backend = vault_mount.db.path
  name    = "readonly"
  db_name = vault_database_secret_backend_connection.docdb.name
  creation_statements = [
    "{ \"db\": \"admin\", \"roles\": [{\"role\": \"read\", \"db\": \"test\"}] }",
  ]
  default_ttl = 60 * 60      # 1 hour
  max_ttl     = 24 * 60 * 60 # 24 hours
}

resource "vault_database_secret_backend_role" "readwrite" {
  backend = vault_mount.db.path
  name    = "readwrite"
  db_name = vault_database_secret_backend_connection.docdb.name
  creation_statements = [
    "{ \"db\": \"admin\", \"roles\": [{\"role\": \"readWrite\", \"db\": \"test\"}] }",
  ]
  default_ttl = 60 * 60      # 1 hour
  max_ttl     = 24 * 60 * 60 # 24 hours
}

# JWT Auth Mount
resource "vault_jwt_auth_backend" "jwt" {
  description        = "JWT auth backend for OIDC authentication"
  path               = "jwt"
  oidc_discovery_url = var.jwt_oidc_discovery_url
  bound_issuer       = var.jwt_bound_issuer
}

# JWT Auth Role
resource "vault_jwt_auth_backend_role" "default" {
  backend              = vault_jwt_auth_backend.jwt.path
  role_name            = "default"
  bound_audiences      = ["${var.jwt_bound_audiences}"]
  user_claim           = "preferred_username"
  groups_claim         = "groups"
  role_type            = "jwt"
  verbose_oidc_logging = true
  claim_mappings = {
    "name" = "name"
    "aud"  = "aud"
  }

}

# External Identity Groups
resource "vault_identity_group" "readonly" {
  name     = "readonly"
  type     = "external"
  policies = [vault_policy.readonly.name]
  metadata = {
    "description" = "Readonly access group"
  }
}

resource "vault_identity_group" "readwrite" {
  name     = "readwrite"
  type     = "external"
  policies = [vault_policy.readwrite.name]
  metadata = {
    "description" = "Readwrite access group"
  }
}

# Identity Group Aliases
resource "vault_identity_group_alias" "readonly_alias" {
  name           = var.readonly_group_alias_name
  mount_accessor = vault_jwt_auth_backend.jwt.accessor
  canonical_id   = vault_identity_group.readonly.id
}

resource "vault_identity_group_alias" "readwrite_alias" {
  name           = var.readwrite_group_alias_name
  mount_accessor = vault_jwt_auth_backend.jwt.accessor
  canonical_id   = vault_identity_group.readwrite.id
}

# resource "vault_audit_request_header" "x_jwtauth_sub" {
#   name = "X-JWTAuth-Sub"
#   hmac = false
# }

# resource "vault_audit_request_header" "x_jwtauth_aud" {
#   name = "X-JWTAuth-Aud"
#   hmac = false
# }
