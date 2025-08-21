# Generate random suffix for unique resource naming
resource "random_string" "suffix" {
  length  = 3
  special = false
  upper   = false
}

# Create resource name prefix with suffix
locals {
  name_prefix = "${var.resource_prefix}-${random_string.suffix.result}"
}

# Module 1: HCP Infrastructure (HVN + Vault)
module "hcp_infra" {
  source = "./modules/hcp-infra"

  hvn_id           = "${local.name_prefix}-${var.hvn_id}"
  hvn_cidr_block   = var.hvn_cidr_block
  hvn_region       = var.hvn_region
  vault_cluster_id = "${local.name_prefix}-${var.vault_cluster_id}"
  vault_tier       = var.vault_tier

  tags = var.common_tags
}

# Module 2: AWS VPC and VPC Peering
module "aws_networking" {
  source = "./modules/aws-networking"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  # HCP HVN information for peering
  hvn_id         = module.hcp_infra.hvn_id
  hvn_self_link  = module.hcp_infra.hvn_self_link
  hvn_cidr_block = var.hvn_cidr_block

  tags = var.common_tags
}

# Module 3: AWS DocumentDB
module "documentdb" {
  source = "./modules/documentdb"

  name_prefix        = local.name_prefix
  cluster_identifier = "${local.name_prefix}-${var.docdb_cluster_identifier}"
  master_username    = var.docdb_master_username
  master_password    = var.docdb_master_password
  instance_class     = var.docdb_instance_class
  instance_count     = var.docdb_instance_count

  vpc_id              = module.aws_networking.vpc_id
  private_subnet_ids  = module.aws_networking.private_subnet_ids
  allowed_cidr_blocks = [var.vpc_cidr, var.hvn_cidr_block]

  tags = var.common_tags
}

# Module 4: Bastion Host
module "bastion" {
  source = "./modules/bastion"

  name_prefix   = local.name_prefix
  instance_type = var.bastion_instance_type
  key_name      = "${local.name_prefix}-${var.bastion_key_name}"

  vpc_id           = module.aws_networking.vpc_id
  public_subnet_id = module.aws_networking.public_subnet_ids[0]
  documentdb_sg_id = module.documentdb.documentdb_security_group_id

  vault_public_endpoint_url = module.hcp_infra.vault_public_endpoint_url
  vault_admin_token         = module.hcp_infra.vault_admin_token

  docdb_cluster_endpoint = module.documentdb.cluster_endpoint
  docdb_username         = var.docdb_master_username
  docdb_password         = var.docdb_master_password

  # JWT Auth configuration
  jwt_oidc_discovery_url     = var.jwt_oidc_discovery_url
  jwt_bound_issuer           = var.jwt_bound_issuer
  jwt_bound_audiences        = var.jwt_bound_audiences
  readonly_group_alias_name  = var.readonly_group_alias_name
  readwrite_group_alias_name = var.readwrite_group_alias_name

  tags = var.common_tags
}

# Module 5: AWS EKS Cluster
module "aws_eks" {
  source = "./modules/aws-eks"

  name_prefix        = local.name_prefix
  vpc_id             = module.aws_networking.vpc_id
  private_subnet_ids = module.aws_networking.private_subnet_ids

  kubernetes_version  = var.eks_kubernetes_version
  public_access_cidrs = var.eks_public_access_cidrs
  cluster_log_types   = var.eks_cluster_log_types
  kubeconfig_path     = var.eks_kubeconfig_path

  # Node Group Configuration
  node_group_capacity_type  = var.eks_node_group_capacity_type
  node_group_instance_types = var.eks_node_group_instance_types
  node_group_desired_size   = var.eks_node_group_desired_size
  node_group_max_size       = var.eks_node_group_max_size
  node_group_min_size       = var.eks_node_group_min_size

  tags = var.common_tags
}

# Module 6: Azure AD Applications
module "azure_ad_app" {
  source = "./modules/azure-ad-app"

}
