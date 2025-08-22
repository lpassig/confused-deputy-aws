variable "docdb_cluster_endpoint" {
  description = "DocumentDB cluster endpoint"
  type        = string
}

variable "docdb_username" {
  description = "DocumentDB username"
  type        = string
}

variable "docdb_password" {
  description = "DocumentDB password"
  type        = string
  sensitive   = true
}

variable "jwt_oidc_discovery_url" {
  description = "OIDC Discovery URL for JWT auth"
  type        = string
}

variable "jwt_bound_audiences" {
  description = "List of audiences that are allowed to authenticate"
  type        = string
}

variable "jwt_bound_issuer" {
  description = "OIDC Bound Issuer for JWT auth"
  type        = string
}

variable "readonly_group_alias_name" {
  description = "Name for the readonly identity group alias"
  type        = string
}

variable "readwrite_group_alias_name" {
  description = "Name for the readwrite identity group alias"
  type        = string
}