# ========================================
# Products MCP Application 
# ========================================

# Generate UUIDs for the main Products API scopes
resource "random_uuid" "products_mcp_read_id" {}
resource "random_uuid" "products_mcp_write_id" {}
resource "random_uuid" "products_mcp_list_id" {}
resource "random_uuid" "products_mcp_delete_id" {}

resource "azuread_application" "products_mcp" {
  display_name     = "ProductsMCP"
  sign_in_audience = var.sign_in_audience
  owners           = var.owners
  tags             = var.tags

  # Configure group membership claims
  group_membership_claims = var.include_groups_claim ? ["SecurityGroup"] : []

  # API configuration - expose the Products API scopes
  api {
    mapped_claims_enabled          = false
    requested_access_token_version = var.api_access_version

    # Products API OAuth2 permission scopes
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to read products on behalf of the signed-in user."
      admin_consent_display_name = "Read products"
      enabled                    = true
      id                         = random_uuid.products_mcp_read_id.result
      type                       = "User"
      user_consent_description   = "Allow the application to read products on your behalf."
      user_consent_display_name  = "Read products"
      value                      = "Products.Read"
    }

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to write products on behalf of the signed-in user."
      admin_consent_display_name = "Write products"
      enabled                    = true
      id                         = random_uuid.products_mcp_write_id.result
      type                       = "User"
      user_consent_description   = "Allow the application to write products on your behalf."
      user_consent_display_name  = "Write products"
      value                      = "Products.Write"
    }

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to list products on behalf of the signed-in user."
      admin_consent_display_name = "List products"
      enabled                    = true
      id                         = random_uuid.products_mcp_list_id.result
      type                       = "User"
      user_consent_description   = "Allow the application to list products on your behalf."
      user_consent_display_name  = "List products"
      value                      = "Products.List"
    }

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to delete products on behalf of the signed-in user."
      admin_consent_display_name = "Delete products"
      enabled                    = true
      id                         = random_uuid.products_mcp_delete_id.result
      type                       = "User"
      user_consent_description   = "Allow the application to delete products on your behalf."
      user_consent_display_name  = "Delete products"
      value                      = "Products.Delete"
    }
  }


  # Web platform configuration
  web {
    homepage_url = "https://localhost"

    # Configure implicit grant settings
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  # Optional claims configuration for groups
  optional_claims {
    access_token {
      name = "groups"
    }
    id_token {
      name = "groups"
    }
    saml2_token {
      name = "groups"
    }
  }
}

data "azuread_application" "products_mcp" {
  client_id = azuread_application.products_mcp.client_id
}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
}

resource "azuread_service_principal" "products_mcp" {
  client_id = azuread_application.products_mcp.client_id
}

resource "azuread_service_principal_delegated_permission_grant" "products_mcp" {
  service_principal_object_id          = azuread_service_principal.products_mcp.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["User.Read.All", "Group.Read.All"]
}

# Set the identifier URI for the Products MCP application
resource "azuread_application_identifier_uri" "products_mcp" {
  application_id = azuread_application.products_mcp.id
  identifier_uri = "api://${azuread_application.products_mcp.client_id}"
}


# ========================================
# Products Agent Application
# ========================================

# Generate UUIDs for Products Agent API scopes
resource "random_uuid" "products_agent_invoke_scope_id" {}

# Products Agent Application
resource "azuread_application" "products_agent" {
  display_name     = "ProductsAgent"
  sign_in_audience = "AzureADMyOrg"
  owners           = var.owners
  tags             = ["terraform-managed", "products-agent"]

  # Configure group membership claims
  group_membership_claims = var.include_groups_claim ? ["SecurityGroup"] : []


  # API configuration - expose the Products Agent API scopes
  api {
    mapped_claims_enabled          = false
    requested_access_token_version = 2

    # Products Agent API OAuth2 permission scopes
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to invoke products agent on behalf of the signed-in user."
      admin_consent_display_name = "Invoke products agent"
      enabled                    = true
      id                         = random_uuid.products_agent_invoke_scope_id.result
      type                       = "User"
      user_consent_description   = "Allow the application to invoke products agent on your behalf."
      user_consent_display_name  = "Invoke products agent"
      value                      = "Agent.Invoke"
    }
  }

  # Web platform configuration
  web {
    homepage_url = "https://localhost"

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

  required_resource_access {
    resource_app_id = azuread_application.products_mcp.client_id #data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = azuread_service_principal.products_mcp.oauth2_permission_scope_ids["Products.Read"]
      type = "Scope"
    }
    resource_access {
      id   = azuread_service_principal.products_mcp.oauth2_permission_scope_ids["Products.List"]
      type = "Scope"
    }
    resource_access {
      id   = azuread_service_principal.products_mcp.oauth2_permission_scope_ids["Products.Write"]
      type = "Scope"
    }
    resource_access {
      id   = azuread_service_principal.products_mcp.oauth2_permission_scope_ids["Products.Delete"]
      type = "Scope"
    }
  }

  optional_claims {
    access_token {
      name = "groups"
    }
    id_token {
      name = "groups"
    }
    saml2_token {
      name = "groups"
    }
  }
}

data "azuread_application" "products_agent" {
  client_id = azuread_application.products_agent.client_id
}

resource "azuread_service_principal" "products_agent" {
  client_id = azuread_application.products_agent.client_id
}

resource "azuread_service_principal_delegated_permission_grant" "products_agent" {
  service_principal_object_id          = azuread_service_principal.products_agent.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["User.Read.All", "Group.Read.All"]
}

resource "azuread_service_principal_delegated_permission_grant" "products_agent_products_mcp" {
  service_principal_object_id          = azuread_service_principal.products_agent.object_id
  resource_service_principal_object_id = azuread_service_principal.products_mcp.object_id
  claim_values                         = ["Products.Read", "Products.Write", "Products.List", "Products.Delete"]
}

# resource "azuread_application_api_access" "products_agent_products_mcp" {
#   application_id = azuread_application.products_agent.id
#   api_client_id  = azuread_application.products_mcp.client_id

#   scope_ids = [
#     azuread_application.products_mcp.oauth2_permission_scope_ids["Products.Read"],
#     azuread_application.products_mcp.oauth2_permission_scope_ids["Products.Write"],
#     azuread_application.products_mcp.oauth2_permission_scope_ids["Products.List"],
#   ]
# }

# Set the identifier URI for the Products Agent API application
resource "azuread_application_identifier_uri" "products_agent" {
  application_id = azuread_application.products_agent.id
  identifier_uri = "api://${azuread_application.products_agent.client_id}"
}

# Create client secret for the Products Agent API service principal
resource "azuread_application_password" "products_agent" {
  application_id = azuread_application.products_agent.id
  display_name   = "terraform-managed-products-agent-secret"

  # Secret expires in 2 years
  end_date = timeadd(timestamp(), "17520h") # 2 years
}

# ========================================
# Products Web Application 
# ========================================

# Products Web Application
resource "azuread_application" "products_web" {
  display_name     = "ProductsWeb"
  sign_in_audience = var.sign_in_audience
  owners           = var.owners
  tags             = var.tags

  # Configure group membership claims
  group_membership_claims = var.include_groups_claim ? ["SecurityGroup"] : []

  required_resource_access {
    resource_app_id = azuread_application.products_agent.client_id #data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = azuread_service_principal.products_agent.oauth2_permission_scope_ids["Agent.Invoke"]
      type = "Scope"
    }
  }

  # Web platform configuration
  web {
    homepage_url = "https://localhost"

    # Configure implicit grant settings
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
    redirect_uris = [
      "http://localhost:8501/oauth2callback",
    ]
  }

  # Optional claims configuration for groups
  optional_claims {
    access_token {
      name = "groups"
    }
    id_token {
      name = "groups"
    }
    saml2_token {
      name = "groups"
    }
  }
}

resource "azuread_service_principal" "products_web" {
  client_id = azuread_application.products_web.client_id
}

resource "azuread_service_principal_delegated_permission_grant" "products_web_msgraph" {
  service_principal_object_id          = azuread_service_principal.products_web.object_id
  resource_service_principal_object_id = data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["User.Read.All", "Group.Read.All"]
}

resource "azuread_service_principal_delegated_permission_grant" "products_web_products_agent" {
  service_principal_object_id          = azuread_service_principal.products_web.object_id
  resource_service_principal_object_id = azuread_service_principal.products_agent.object_id #data.azuread_service_principal.msgraph.object_id
  claim_values                         = ["Agent.Invoke"]
}


# resource "azuread_application_api_access" "products_web_products_agent" {
#   application_id = azuread_application.products_web.id
#   api_client_id  = azuread_application.products_agent.client_id

#   scope_ids = [
#     azuread_application.products_agent.oauth2_permission_scope_ids["Agent.Invoke"],
#   ]
# }

# Set the identifier URI for the Products Web application
resource "azuread_application_identifier_uri" "products_web" {
  application_id = azuread_application.products_web.id
  identifier_uri = "api://${azuread_application.products_web.client_id}"
}

# Create client secret for the Products Web application
resource "azuread_application_password" "products_web" {
  application_id = azuread_application.products_web.id
  display_name   = "terraform-managed-products-web-secret"

  # Secret expires in 2 years
  end_date = timeadd(timestamp(), "17520h") # 2 years
}
