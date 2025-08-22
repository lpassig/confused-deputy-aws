# Generate TLS private key for SSH
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS Key Pair from generated public key
resource "aws_key_pair" "main" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = merge(var.tags, {
    Name = var.key_name
  })
}

# Save private key to current directory
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${var.key_name}.pem"
  file_permission = "0600"
}

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create security group for bastion host
resource "aws_security_group" "bastion" {
  name_prefix = "${var.name_prefix}-bastion-"
  vpc_id      = var.vpc_id

  description = "Security group for bastion host"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Add rule to DocumentDB security group to allow access from bastion
resource "aws_security_group_rule" "documentdb_from_bastion" {
  type                     = "ingress"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = var.documentdb_sg_id
  description              = "DocumentDB access from bastion host"
}

# Create bastion host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = var.public_subnet_id
  iam_instance_profile   = aws_iam_instance_profile.bastion_profile.name

  associate_public_ip_address = true

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    vault_public_endpoint_url = var.vault_public_endpoint_url
    vault_admin_token         = var.vault_admin_token
    docdb_cluster_endpoint    = var.docdb_cluster_endpoint
    docdb_username            = var.docdb_username
    docdb_password            = var.docdb_password
  }))

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-host"
  })

  lifecycle {
    create_before_destroy = true
  }
}
