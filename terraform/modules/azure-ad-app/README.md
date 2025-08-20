# Azure AD Applications Module

This Terraform module creates multiple Azure Active Directory applications as separate resources within the same module. It provides a main configurable application plus additional predefined applications for different use cases.

## Features

- **Primary Application**: Configurable main application (Products MCP) with custom settings
- **Additional Applications**: Pre-configured Analytics API and Simple Client applications
- **Products API Scopes**: Exposes OAuth2 permission scopes for Products (Read, Write, List, Delete)
- **Analytics API Scopes**: Exposes OAuth2 permission scopes for Analytics (Read, Write)
- **Microsoft Graph Permissions**: Configurable Microsoft Graph API permissions per application
- **Group Claims**: Configurable group claims in tokens for the main application
- **Identifier URI**: Automatic identifier URI configuration using client ID (`api://{client_id}`)
- **Service Principals**: Creates service principals for all applications
- **Client Secrets**: Generates client secrets with 2-year expiration (where needed)

## Applications Created

1. **Products MCP Application** (configurable via variables)
   - Configurable display name, audience, and settings
   - Products API scopes: `Products.Read`, `Products.Write`, `Products.List`, `Products.Delete`
   - Microsoft Graph permissions: `Group.ReadAll`, `User.ReadAll`
   - Groups claim support
   - Client secret included

2. **Analytics API Application** (predefined)
   - Fixed configuration for analytics use cases
   - Analytics API scopes: `Analytics.Read`, `Analytics.Write`
   - Microsoft Graph permissions: `User.ReadAll`
   - No groups claim
   - Client secret included

3. **Simple Client Application** (predefined)
   - Basic client application for authentication only
   - No API scopes (doesn't expose APIs)
   - Microsoft Graph permissions: `User.Read`
   - No groups claim
   - No client secret (public client)

## Usage

```hcl
module "azure_ad_app" {
  source = "./modules/azure-ad-app"

  # Configure the main Products MCP Application
  application_name      = "ProductsMCP"
  display_name         = "Products MCP Application"
  include_groups_claim = true
  sign_in_audience     = "AzureADMyOrg"
  api_access_version   = 2
  
  tags = ["terraform-managed", "products-api"]
  
  # Optionally set owners (replace with actual object IDs)
  # owners = ["user-object-id-1", "user-object-id-2"]
}
```

## Variables

These variables configure the main Products MCP application. The other applications (Analytics API and Simple Client) have predefined configurations.

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| application_name | Name of the Azure AD application | `string` | `"ProductsMCP"` | no |
| display_name | Display name for the Azure AD application | `string` | `"Products MCP Application"` | no |
| sign_in_audience | The Microsoft account types supported | `string` | `"AzureADMyOrg"` | no |
| include_groups_claim | Whether to include groups claim in the token | `bool` | `true` | no |
| api_access_version | The access token version expected by this resource | `number` | `2` | no |
| tags | A set of tags to apply to the application | `set(string)` | `["terraform-managed", "products-api"]` | no |
| owners | A set of object IDs of principals for ownership | `set(string)` | `[]` | no |

## Outputs

### Products MCP Application (Primary)

| Name | Description |
|------|-------------|
| application_id | The application (client) ID of the Products MCP Azure AD application |
| application_object_id | The object ID of the Products MCP Azure AD application |
| client_id | The client ID of the Products MCP Azure AD application (same as application_id) |
| client_secret | The client secret of the Products MCP Azure AD application (sensitive) |
| service_principal_id | The object ID of the Products MCP service principal |
| service_principal_object_id | The object ID of the Products MCP service principal |
| identifier_uri | The identifier URI of the Products MCP application |
| api_scopes | The OAuth2 permission scopes exposed by the Products MCP application |
| microsoft_graph_permissions | The Microsoft Graph API permissions granted to the Products MCP application |
| display_name | The display name of the Products MCP Azure AD application |

### Analytics API Application

| Name | Description |
|------|-------------|
| analytics_application_id | The application (client) ID of the Analytics API Azure AD application |
| analytics_application_object_id | The object ID of the Analytics API Azure AD application |
| analytics_client_id | The client ID of the Analytics API Azure AD application |
| analytics_client_secret | The client secret of the Analytics API Azure AD application (sensitive) |
| analytics_service_principal_id | The object ID of the Analytics API service principal |
| analytics_service_principal_object_id | The object ID of the Analytics API service principal |
| analytics_identifier_uri | The identifier URI of the Analytics API application |
| analytics_api_scopes | The OAuth2 permission scopes exposed by the Analytics API application |
| analytics_display_name | The display name of the Analytics API Azure AD application |

### Simple Client Application

| Name | Description |
|------|-------------|
| simple_client_application_id | The application (client) ID of the Simple Client Azure AD application |
| simple_client_application_object_id | The object ID of the Simple Client Azure AD application |
| simple_client_id | The client ID of the Simple Client Azure AD application |
| simple_client_service_principal_id | The object ID of the Simple Client service principal |
| simple_client_service_principal_object_id | The object ID of the Simple Client service principal |
| simple_client_display_name | The display name of the Simple Client Azure AD application |

### Summary Outputs

| Name | Description |
|------|-------------|
| all_applications_summary | Summary of all created Azure AD applications |
| all_client_secrets | All client secrets for applications that have them (sensitive) |

## API Scopes

The module exposes the following OAuth2 permission scopes:

- `api://{client_id}/Products.Read` - Allow reading products
- `api://{client_id}/Products.Write` - Allow writing products  
- `api://{client_id}/Products.List` - Allow listing products
- `api://{client_id}/Products.Delete` - Allow deleting products

## Microsoft Graph Permissions

The application is granted the following Microsoft Graph API permissions:

- `Group.ReadAll` - Read all groups (Application permission)
- `User.ReadAll` - Read all users (Application permission)

**Note**: These permissions require admin consent in the Azure portal after the application is created.

## Prerequisites

1. **Azure AD Permissions**: The service principal used by Terraform must have sufficient permissions to:
   - Create applications in Azure AD
   - Create service principals
   - Grant API permissions

2. **Provider Configuration**: Ensure the Azure AD provider is configured with proper credentials:

```hcl
provider "azuread" {
  tenant_id     = var.azure_tenant_id
  client_id     = var.azure_client_id
  client_secret = var.azure_client_secret
}
```

## Post-Deployment Steps

After running Terraform:

1. **Admin Consent**: Navigate to the Azure portal and grant admin consent for the Microsoft Graph API permissions
2. **API Permissions**: Verify that the API permissions are correctly configured
3. **Testing**: Test the OAuth2 flows using the generated client ID and secret

## Security Considerations

- The client secret is marked as sensitive and expires in 2 years
- Store the client secret securely (e.g., in Azure Key Vault)
- Regularly rotate the client secret before expiration
- Review and minimize the Microsoft Graph permissions if not all are needed
