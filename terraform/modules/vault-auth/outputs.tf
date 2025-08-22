# Vault JWT Auth outputs
output "jwt_auth_accessor" {
  description = "Accessor of the JWT auth backend"
  value       = vault_jwt_auth_backend.jwt.accessor
}

output "jwt_auth_path" {
  description = "Path of the JWT auth backend"
  value       = vault_jwt_auth_backend.jwt.path
}

output "readonly_group_id" {
  description = "ID of the readonly identity group"
  value       = vault_identity_group.readonly.id
}

output "readwrite_group_id" {
  description = "ID of the readwrite identity group"
  value       = vault_identity_group.readwrite.id
}