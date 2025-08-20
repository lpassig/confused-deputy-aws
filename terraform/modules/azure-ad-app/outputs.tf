# ========================================
# PRODUCTS MCP APPLICATION OUTPUTS
# ========================================

output "products_mcp_client_id" {
  description = "The client ID of the Products MCP Azure AD application (same as application_id)"
  value       = azuread_application.products_mcp.client_id
}

output "products_mcp_scopes" {
  description = "The OAuth2 permission scopes of the Products MCP Azure AD application"
  value       = [for scope in data.azuread_application.products_mcp.api[0].oauth2_permission_scopes : "api://${data.azuread_application.products_mcp.client_id}/${scope.value}"]
}

# ========================================
# PRODUCTS AGENT APPLICATION OUTPUTS
# ========================================

output "products_agent_client_id" {
  description = "The client ID of the Products Agent Azure AD application (same as application_id)"
  value       = azuread_application.products_agent.client_id
}

output "products_agent_client_secret" {
  description = "The client secret of the Products Agent Azure AD application"
  value       = azuread_application_password.products_agent.value
  sensitive   = true
}

output "products_agent_scopes" {
  description = "The OAuth2 permission scopes of the Products Agent Azure AD application"
  value       = [for scope in data.azuread_application.products_agent.api[0].oauth2_permission_scopes : "api://${data.azuread_application.products_agent.client_id}/${scope.value}"]
}

# ========================================
# PRODUCTS WEB APPLICATION OUTPUTS
# ========================================

output "products_web_client_id" {
  description = "The client ID of the Products Web Azure AD application (same as application_id)"
  value       = azuread_application.products_web.client_id
}

output "products_web_client_secret" {
  description = "The client secret of the Products Web Azure AD application"
  value       = azuread_application_password.products_web.value
  sensitive   = true
}


