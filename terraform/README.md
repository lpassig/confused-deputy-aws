# HCP Vault + AWS DocumentDB Infrastructure

This Terraform project creates a complete infrastructure setup with HashiCorp Cloud Platform (HCP) Vault and AWS DocumentDB, connected via VPC peering and accessible through a bastion host.

## Architecture Overview

The infrastructure consists of four main components:

1. **HCP Infrastructure**: HashiCorp Virtual Network (HVN) and Vault Plus cluster
2. **AWS Networking**: VPC with public/private subnets and VPC peering with HCP HVN
3. **DocumentDB**: AWS DocumentDB cluster with security groups for network access
4. **Bastion Host**: Ubuntu EC2 instance with MongoDB tools for database access

### Resource Naming Convention

All resources are automatically prefixed with a customizable prefix plus a random 3-character suffix to ensure uniqueness:
- **Format**: `{resource_prefix}-{3-char-random-suffix}`
- **Default prefix**: `hcp-vault-docdb`
- **Example**: `hcp-vault-docdb-abc` (where `abc` is randomly generated)
- **Benefits**: Prevents naming conflicts, easy resource identification, supports multiple deployments

## Prerequisites

- **Terraform** >= 1.5
- **AWS CLI** configured with appropriate credentials
- **HCP CLI** configured with appropriate credentials (or HCP service principal)
- An **HCP account** with billing enabled

## Quick Start

1. **Clone and Navigate**
   ```bash
   cd terraform
   ```

2. **Configure Variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   
   Edit `terraform.tfvars` and set:
   - `docdb_master_password` to a secure password
   - Adjust other values as needed (regions, CIDR blocks, etc.)

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Plan Deployment**
   ```bash
   terraform plan
   ```

5. **Deploy Infrastructure**
   ```bash
   terraform apply
   ```

6. **Initialize DocumentDB**
   ```bash
   ./init-documentdb.sh
   ```

## Module Structure

```
├── main.tf                    # Root module configuration
├── variables.tf              # Root module variables
├── outputs.tf               # Root module outputs
├── terraform.tf             # Provider configurations
├── terraform.tfvars.example # Example variables file
├── init-documentdb.sh       # DocumentDB initialization script
└── modules/
    ├── hcp-infrastructure/   # HCP HVN and Vault cluster
    ├── aws-networking/       # VPC, subnets, and peering
    ├── documentdb/          # DocumentDB cluster and security
    └── bastion/             # Bastion host with SSH access
```

### Module 1: HCP Infrastructure

Creates:
- **HCP HVN** with non-overlapping CIDR (default: `172.25.16.0/20`)
- **HCP Vault Plus cluster** with public endpoint enabled
- **Admin token** for Vault cluster access

### Module 2: AWS Networking

Creates:
- **VPC** with DNS support enabled (default: `10.0.0.0/16`)
- **Public subnets** with Internet Gateway access
- **Private subnets** with NAT Gateway access
- **VPC Peering** connection between AWS VPC and HCP HVN
- **Routing tables** with proper routes for HVN access

### Module 3: DocumentDB

Creates:
- **DocumentDB cluster** with encryption enabled
- **DocumentDB instances** (default: 1x db.t3.medium)
- **Security group** allowing access from VPC and HVN CIDR blocks
- **Parameter group** with TLS disabled for easier connection
- **Subnet group** spanning private subnets

### Module 4: Bastion Host

Creates:
- **SSH key pair** with private key saved locally
- **Ubuntu 22.04 EC2 instance** (default: t3.medium)
- **Security group** allowing SSH from internet
- **DocumentDB access rule** added to DocumentDB security group
- **Pre-installed MongoDB tools** for database connectivity

## Network Configuration

### CIDR Blocks (Non-Overlapping)
- **HCP HVN**: `172.25.16.0/20` (172.25.16.1 - 172.25.31.254)
- **AWS VPC**: `10.0.0.0/16` (10.0.0.1 - 10.0.255.254)
- **Public Subnets**: `10.0.1.0/24`, `10.0.2.0/24`
- **Private Subnets**: `10.0.10.0/24`, `10.0.20.0/24`

### Security Groups
- **DocumentDB**: Allows port 27017 from VPC and HVN CIDR blocks
- **Bastion**: Allows SSH (port 22) from internet, full egress

## Connecting to DocumentDB

### Via Bastion Host

1. **SSH to Bastion**
   ```bash
   ssh -i $(terraform output -raw bastion_ssh_key_path) ubuntu@$(terraform output -raw bastion_public_ip)
   ```

2. **Connect to DocumentDB**
   ```bash
   ./connect-to-documentdb.sh <endpoint> <username> <password> test
   ```

3. **Query Products Collection**
   ```javascript
   db.products.find().pretty()
   db.products.countDocuments()
   db.products.find({"category": "Electronics"})
   ```

### Connection Details

Get connection details from Terraform outputs:
```bash
terraform output documentdb_cluster_endpoint
terraform output bastion_public_ip
terraform output bastion_ssh_key_path
```

## DocumentDB Products Collection

The initialization script creates a `products` collection in the `test` database with:

- **5 sample products** with realistic data
- **Unique index** on SKU field
- **Index** on category field for filtering
- **Fields**: name, description, price, category, sku, inStock, quantity, createdAt, updatedAt

### Sample Products
- Laptop ($1299.99, Electronics, In Stock)
- Wireless Mouse ($29.99, Accessories, In Stock) 
- Mechanical Keyboard ($149.99, Accessories, Out of Stock)
- 4K Monitor ($399.99, Electronics, In Stock)
- Webcam ($79.99, Accessories, In Stock)

## HCP Vault Access

### Connection Details
```bash
# Get Vault URL and admin token
terraform output vault_public_endpoint_url
terraform output vault_admin_token
```

### Vault CLI Setup
```bash
export VAULT_ADDR=$(terraform output -raw vault_public_endpoint_url)
export VAULT_TOKEN=$(terraform output -raw vault_admin_token)
vault status
```

## Important Notes

### Security Considerations
- **DocumentDB TLS is disabled** for easier connection from bastion
- **Bastion SSH** is open to internet (0.0.0.0/0) - restrict in production
- **Vault admin token** is sensitive - store securely
- **Private key** is stored locally - backup securely

### Cost Optimization
- **HCP Vault Plus** tier has hourly costs
- **DocumentDB db.t3.medium** instances have hourly costs
- **NAT Gateways** have hourly costs and data transfer charges
- Consider using **Vault starter_small** tier for development

### Customization
- Adjust **instance sizes** in `terraform.tfvars`
- Modify **CIDR blocks** to avoid conflicts
- Change **availability zones** for your region
- Update **instance counts** for DocumentDB

## Troubleshooting

### Common Issues

1. **HCP Provider Authentication**
   ```bash
   # Set HCP credentials
   export HCP_CLIENT_ID="your-client-id"
   export HCP_CLIENT_SECRET="your-client-secret"
   ```

2. **AWS Provider Authentication**
   ```bash
   # Configure AWS CLI
   aws configure
   ```

3. **Bastion Connection Issues**
   ```bash
   # Check security groups allow SSH
   # Verify key permissions: chmod 600 *.pem
   ```

4. **DocumentDB Connection Issues**
   ```bash
   # Verify bastion can reach DocumentDB
   # Check security group rules
   # Confirm endpoint is correct
   ```

### Resource Cleanup

```bash
terraform destroy
```

**Note**: HCP Vault cluster has `prevent_destroy = true` lifecycle rule. Remove this before destroying if needed.

## Outputs Reference

| Output | Description |
|--------|-------------|
| `resource_name_prefix` | Generated resource name prefix with random suffix |
| `hvn_id` | HCP HVN identifier |
| `vault_public_endpoint_url` | Vault cluster public URL |
| `vault_admin_token` | Vault admin token (sensitive) |
| `vpc_id` | AWS VPC identifier |
| `documentdb_cluster_endpoint` | DocumentDB connection endpoint |
| `bastion_public_ip` | Bastion host public IP |
| `bastion_ssh_key_path` | Path to SSH private key |
| `ssh_connection_command` | Ready-to-use SSH command |

## Variables Reference

### Required Variables
- `docdb_master_password` - DocumentDB master password (sensitive)

### Optional Variables
- `resource_prefix` - Prefix for all resource names (default: hcp-vault-docdb)
- `aws_region` - AWS region (default: us-east-1)
- `hvn_cidr_block` - HCP HVN CIDR (default: 172.25.16.0/20)
- `vpc_cidr` - AWS VPC CIDR (default: 10.0.0.0/16)
- `vault_tier` - HCP Vault tier (default: plus)
- `docdb_instance_class` - DocumentDB instance type (default: db.t3.medium)
- `bastion_instance_type` - Bastion EC2 type (default: t3.medium)

## Support

For issues with this Terraform configuration:
1. Check the troubleshooting section above
2. Verify all prerequisites are met
3. Ensure proper authentication for HCP and AWS
4. Review Terraform logs with `TF_LOG=DEBUG terraform apply`
