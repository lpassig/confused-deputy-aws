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
module "hcp_vault" {
  source = "./modules/hcp-vault"

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
  hvn_id         = module.hcp_vault.hvn_id
  hvn_self_link  = module.hcp_vault.hvn_self_link
  hvn_cidr_block = var.hvn_cidr_block

  tags = var.common_tags
}

# Module 3: AWS DocumentDB
module "aws_documentdb" {
  source = "./modules/aws-documentdb"

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

# Module 4: ECR Repositories
module "ecr" {
  source      = "./modules/ecr"
  name_prefix = local.name_prefix
  tags        = var.common_tags
}

# Module 5: Bastion Host
module "bastion" {
  source        = "./modules/bastion"
  name_prefix   = local.name_prefix
  instance_type = var.bastion_instance_type
  key_name      = "${local.name_prefix}-${var.bastion_key_name}"

  vpc_id            = module.aws_networking.vpc_id
  public_subnet_id  = module.aws_networking.public_subnet_ids[0]
  public_subnet_ids = module.aws_networking.public_subnet_ids
  documentdb_sg_id  = module.aws_documentdb.documentdb_security_group_id

  vault_public_endpoint_url = module.hcp_vault.vault_public_endpoint_url
  vault_admin_token         = module.hcp_vault.vault_admin_token

  docdb_cluster_endpoint = module.aws_documentdb.cluster_endpoint
  docdb_username         = var.docdb_master_username
  docdb_password         = var.docdb_master_password

  aws_account_id = data.aws_caller_identity.current.account_id

  tags = var.common_tags
}


# Module 6: Azure AD Applications
module "azure_ad_app" {
  source           = "./modules/azure-ad-app"
  alb_https_url    = module.bastion.alb_https_url
  ad_user_password = var.ad_user_password
}

# Module 7: Vault Authentication and Database Configuration
module "vault_auth" {
  source = "./modules/vault-auth"

  docdb_cluster_endpoint = module.aws_documentdb.cluster_endpoint
  docdb_username         = var.docdb_master_username
  docdb_password         = var.docdb_master_password

  # JWT Auth configuration
  jwt_oidc_discovery_url     = var.jwt_oidc_discovery_url
  jwt_bound_issuer           = var.jwt_bound_issuer
  jwt_bound_audiences        = module.azure_ad_app.products_mcp_client_id
  readonly_group_alias_name  = module.azure_ad_app.dbread_group_id  #var.readonly_group_alias_name
  readwrite_group_alias_name = module.azure_ad_app.dbadmin_group_id #var.readwrite_group_alias_name

  depends_on = [module.hcp_vault]
}
