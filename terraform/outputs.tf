# Resource naming
output "resource_name_prefix" {
  description = "The generated resource name prefix with random suffix"
  value       = local.name_prefix
}

# HCP Infrastructure outputs
# output "hvn_id" {
#   description = "ID of the HVN"
#   value       = module.hcp_infra.hvn_id
# }

# output "hvn_cidr_block" {
#   description = "CIDR block of the HVN"
#   value       = module.hcp_infra.hvn_cidr_block
# }

# output "vault_cluster_id" {
#   description = "ID of the Vault cluster"
#   value       = module.hcp_infra.vault_cluster_id
# }

output "vault_private_endpoint_url" {
  description = "Private endpoint URL of the Vault cluster"
  value       = module.hcp_infra.vault_private_endpoint_url
}

output "vault_public_endpoint_url" {
  description = "Public endpoint URL of the Vault cluster"
  value       = module.hcp_infra.vault_public_endpoint_url
}

output "vault_admin_token" {
  description = "Admin token for the Vault cluster"
  value       = module.hcp_infra.vault_admin_token
  sensitive   = true
}

# AWS Networking outputs
# output "vpc_id" {
#   description = "ID of the VPC"
#   value       = module.aws_networking.vpc_id
# }

# output "vpc_cidr_block" {
#   description = "CIDR block of the VPC"
#   value       = module.aws_networking.vpc_cidr_block
# }

# output "public_subnet_ids" {
#   description = "IDs of the public subnets"
#   value       = module.aws_networking.public_subnet_ids
# }

# output "private_subnet_ids" {
#   description = "IDs of the private subnets"
#   value       = module.aws_networking.private_subnet_ids
# }

# output "peering_connection_id" {
#   description = "ID of the VPC peering connection"
#   value       = module.aws_networking.peering_connection_id
# }

# DocumentDB outputs
output "documentdb_cluster_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.documentdb.cluster_endpoint
}

# output "documentdb_cluster_reader_endpoint" {
#   description = "DocumentDB cluster reader endpoint"
#   value       = module.documentdb.cluster_reader_endpoint
# }

output "documentdb_cluster_port" {
  description = "DocumentDB cluster port"
  value       = module.documentdb.cluster_port
}

# Bastion outputs
output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = module.bastion.public_ip
}

output "bastion_ssh_key_path" {
  description = "Path to the SSH private key for the bastion host"
  value       = module.bastion.ssh_private_key_path
}

output "ssh_connection_command" {
  description = "SSH command to connect to bastion host"
  value       = "ssh -i ${module.bastion.ssh_private_key_path} ubuntu@${module.bastion.public_ip}"
}

# Vault JWT Auth outputs
# output "jwt_auth_path" {
#   description = "Path of the JWT auth backend"
#   value       = module.bastion.jwt_auth_path
# }

# output "jwt_auth_accessor" {
#   description = "Accessor of the JWT auth backend"
#   value       = module.bastion.jwt_auth_accessor
# }

# output "readonly_group_id" {
#   description = "ID of the readonly identity group"
#   value       = module.bastion.readonly_group_id
# }

# output "readwrite_group_id" {
#   description = "ID of the readwrite identity group"
#   value       = module.bastion.readwrite_group_id
# }

# Products MCP Application outputs (primary)

output "products_mcp_client_id" {
  description = "The client ID of the Products MCP Azure AD application"
  value       = module.azure_ad_app.products_mcp_client_id
}

output "products_agent_client_id" {
  description = "The client ID of the Products Agent Azure AD application"
  value       = module.azure_ad_app.products_agent_client_id
}

output "products_agent_client_secret" {
  description = "The client secret of the Products Agent Azure AD application"
  value       = module.azure_ad_app.products_agent_client_secret
  sensitive   = true
}

output "products_web_client_id" {
  description = "The client ID of the Products Web Azure AD application"
  value       = module.azure_ad_app.products_web_client_id
}

output "products_web_client_secret" {
  description = "The client secret of the Products Web Azure AD application"
  value       = module.azure_ad_app.products_web_client_secret
  sensitive   = true
}

output "products_mcp_scopes" {
  description = "The OAuth2 permission scopes of the Products MCP Azure AD application"
  value       = module.azure_ad_app.products_mcp_scopes
}

output "products_agent_scopes" {
  description = "The OAuth2 permission scopes of the Products Agent Azure AD application"
  value       = module.azure_ad_app.products_agent_scopes
}

# EKS outputs
output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.aws_eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.aws_eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "The Kubernetes server version for the EKS cluster"
  value       = module.aws_eks.cluster_version
}

output "eks_cluster_status" {
  description = "Status of the EKS cluster"
  value       = module.aws_eks.cluster_status
}

output "eks_node_group_name" {
  description = "Name of the EKS Node Group"
  value       = module.aws_eks.node_group_name
}

output "eks_node_group_status" {
  description = "Status of the EKS Node Group"
  value       = module.aws_eks.node_group_status
}

output "eks_kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = module.aws_eks.kubeconfig_path
}

output "eks_kubectl_command" {
  description = "Command to use kubectl with the generated kubeconfig"
  value       = module.aws_eks.kubectl_command
}
