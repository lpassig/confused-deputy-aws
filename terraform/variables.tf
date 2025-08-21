# General variables
variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "ai"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*[a-zA-Z0-9]$", var.resource_prefix)) && length(var.resource_prefix) <= 20
    error_message = "Resource prefix must start with a letter, contain only alphanumeric characters and hyphens, end with alphanumeric character, and be 20 characters or less."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "hcp-vault-documentdb"
    ManagedBy   = "terraform"
  }
}

# HCP variables
variable "hvn_id" {
  description = "The ID of the HVN"
  type        = string
  default     = "ai-vault-hvn"
}

variable "hvn_cidr_block" {
  description = "The CIDR block for the HVN"
  type        = string
  default     = "172.25.16.0/20"
}

variable "hvn_region" {
  description = "The region where the HVN should be created"
  type        = string
  default     = "us-east-2"
}

variable "vault_cluster_id" {
  description = "The ID of the Vault cluster"
  type        = string
  default     = "ai-vault-cluster"
}

variable "vault_tier" {
  description = "The tier of the Vault cluster"
  type        = string
  default     = "standard_small"
}

# AWS VPC variables
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# DocumentDB variables
variable "docdb_cluster_identifier" {
  description = "The cluster identifier for DocumentDB"
  type        = string
  default     = "docdb-cluster"
}

variable "docdb_master_username" {
  description = "Username for the DocumentDB master user"
  type        = string
  default     = "docdbadmin"
}

variable "docdb_master_password" {
  description = "Password for the DocumentDB master user"
  type        = string
  sensitive   = true
}

variable "docdb_instance_class" {
  description = "The compute and memory capacity of the DocumentDB instance"
  type        = string
  default     = "db.t3.medium"
}

variable "docdb_instance_count" {
  description = "Number of DocumentDB instances in the cluster"
  type        = number
  default     = 1
}

# Bastion Host variables
variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.medium"
}

variable "bastion_key_name" {
  description = "Name for the SSH key pair"
  type        = string
  default     = "bastion-key"
}

variable "hcp_client_id" {
  description = "HCP client ID"
  type        = string
}

variable "hcp_client_secret" {
  description = "HCP client secret"
  type        = string
}

# JWT Auth variables
variable "jwt_oidc_discovery_url" {
  description = "OIDC Discovery URL for JWT auth"
  type        = string
}

variable "jwt_bound_issuer" {
  description = "OIDC Bound Issuer for JWT auth"
  type        = string
}

variable "jwt_bound_audiences" {
  description = "List of audiences that are allowed to authenticate"
  type        = string
}

variable "readonly_group_alias_name" {
  description = "Name for the readonly identity group alias"
  type        = string
  default     = "readonly-group"
}

variable "readwrite_group_alias_name" {
  description = "Name for the readwrite identity group alias"
  type        = string
  default     = "readwrite-group"
}

# Azure AD provider variables
variable "azure_tenant_id" {
  description = "The Azure AD tenant ID"
  type        = string
}

variable "azure_client_id" {
  description = "The Azure AD client ID for Terraform provider authentication"
  type        = string
}

variable "azure_client_secret" {
  description = "The Azure AD client secret for Terraform provider authentication"
  type        = string
  sensitive   = true
}

# variable "azure_subscription_id" {
#   description = "The Azure subscription ID"
#   type        = string
# }

# EKS variables
variable "eks_kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "eks_public_access_cidrs" {
  description = "List of CIDR blocks that can access the EKS cluster API publicly"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_cluster_log_types" {
  description = "List of control plane log types to enable for EKS cluster"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# EKS Node Group variables
variable "eks_node_group_capacity_type" {
  description = "Type of capacity associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_node_group_instance_types" {
  description = "List of instance types associated with the EKS Node Group"
  type        = list(string)
  default     = ["m5.large"]
}

variable "eks_node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "eks_node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
}


variable "eks_kubeconfig_path" {
  description = "Path where kubeconfig file will be saved locally"
  type        = string
  default     = "./kubeconfig"
}
