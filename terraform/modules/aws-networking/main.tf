# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# Create public subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-subnet-${count.index + 1}"
    Type = "public"
  })
}

# Create private subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-subnet-${count.index + 1}"
    Type = "private"
  })
}

# Create NAT Gateway EIPs
resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)

  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })
}

# Create NAT Gateways
resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-gw-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# Create public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

# Create private route tables
resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt-${count.index + 1}"
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Get current AWS account ID and region
# data "aws_caller_identity" "current" {}
# data "aws_region" "current" {}
data "aws_arn" "main" {
  arn = aws_vpc.main.arn
}

# Create VPC Peering Connection with HCP HVN
resource "hcp_aws_network_peering" "main" {
  hvn_id          = var.hvn_id
  peering_id      = "${var.name_prefix}-hvn-to-vpc-peering"
  peer_vpc_id     = aws_vpc.main.id
  peer_account_id = aws_vpc.main.owner_id #data.aws_caller_identity.current.account_id
  peer_vpc_region = data.aws_arn.main.region
}

# Accept the VPC peering connection on AWS side
resource "aws_vpc_peering_connection_accepter" "main" {
  vpc_peering_connection_id = hcp_aws_network_peering.main.provider_peering_id
  auto_accept               = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hvn-vpc-peering-accepter"
  })
}

# Create HVN route to VPC
resource "hcp_hvn_route" "hvn_to_vpc" {
  hvn_link         = var.hvn_self_link
  hvn_route_id     = "${var.name_prefix}-hvn-to-vpc-route"
  destination_cidr = aws_vpc.main.cidr_block
  target_link      = hcp_aws_network_peering.main.self_link
}

# Add route to HVN in public route table
resource "aws_route" "public_to_hvn" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = var.hvn_cidr_block
  vpc_peering_connection_id = hcp_aws_network_peering.main.provider_peering_id

  depends_on = [aws_vpc_peering_connection_accepter.main]
}

# Add route to HVN in each private route table
resource "aws_route" "private_to_hvn" {
  count = length(aws_route_table.private)

  route_table_id            = aws_route_table.private[count.index].id
  destination_cidr_block    = var.hvn_cidr_block
  vpc_peering_connection_id = hcp_aws_network_peering.main.provider_peering_id

  depends_on = [aws_vpc_peering_connection_accepter.main]
}
