variable "sign_in_audience" {
  description = "The Microsoft account types that are supported for the current application"
  type        = string
  default     = "AzureADMyOrg"
  validation {
    condition = contains([
      "AzureADMyOrg",
      "AzureADMultipleOrgs", 
      "AzureADandPersonalMicrosoftAccount",
      "PersonalMicrosoftAccount"
    ], var.sign_in_audience)
    error_message = "Sign in audience must be one of: AzureADMyOrg, AzureADMultipleOrgs, AzureADandPersonalMicrosoftAccount, PersonalMicrosoftAccount."
  }
}

variable "include_groups_claim" {
  description = "Whether to include groups claim in the token"
  type        = bool
  default     = true
}

variable "api_access_version" {
  description = "The access token version expected by this resource"
  type        = number
  default     = 2
  validation {
    condition     = contains([1, 2], var.api_access_version)
    error_message = "API access version must be 1 or 2."
  }
}

variable "tags" {
  description = "A set of tags to apply to the application"
  type        = set(string)
  default     = ["terraform-managed", "products-api"]
}

variable "owners" {
  description = "A set of object IDs of principals that will be granted ownership of the application"
  type        = set(string)
  default     = []
}

variable "alb_https_url" {
  description = "The HTTPS URL of the Application Load Balancer"
  type        = string
  default     = "https://products-web.hashidemo.com"
}