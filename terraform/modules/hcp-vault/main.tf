# Create HVN (HashiCorp Virtual Network)
resource "hcp_hvn" "main" {
  hvn_id         = var.hvn_id
  cloud_provider = "aws"
  region         = var.hvn_region
  cidr_block     = var.hvn_cidr_block
}

# Create HCP Vault Plus cluster
resource "hcp_vault_cluster" "main" {
  cluster_id      = var.vault_cluster_id
  hvn_id          = hcp_hvn.main.hvn_id
  tier            = var.vault_tier
  public_endpoint = true

  lifecycle {
    prevent_destroy = false
  }
}

# Get admin token for the Vault cluster
resource "hcp_vault_cluster_admin_token" "main" {
  cluster_id = hcp_vault_cluster.main.cluster_id
}
