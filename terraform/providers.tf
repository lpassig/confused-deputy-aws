
# Provider configurations
provider "hcp" {
  client_id     = var.hcp_client_id
  client_secret = var.hcp_client_secret
}

provider "aws" {
  region = var.aws_region
}

provider "tls" {}

provider "local" {}

provider "random" {}

provider "vault" {
  # Configuration options
  address   = module.hcp_vault.vault_public_endpoint_url
  token     = module.hcp_vault.vault_admin_token
  namespace = "admin"
}

# Azure AD provider for managing Azure Active Directory resources
provider "azuread" {
  tenant_id     = var.azure_tenant_id
  client_id     = var.azure_client_id
  client_secret = var.azure_client_secret
}

# Azure Resource Manager provider (if needed for Azure resources)
provider "azurerm" {
  features {}
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
}
