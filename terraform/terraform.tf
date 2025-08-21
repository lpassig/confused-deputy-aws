terraform {
  required_version = ">= 1.5"
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.94"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.1.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
