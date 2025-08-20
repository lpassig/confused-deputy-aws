# Create DocumentDB subnet group
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.cluster_identifier}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-subnet-group"
  })
}

# Create security group for DocumentDB
resource "aws_security_group" "documentdb" {
  name_prefix = "${var.name_prefix}-docdb-"
  vpc_id      = var.vpc_id

  description = "Security group for DocumentDB cluster"

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "DocumentDB access from allowed CIDR blocks"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-documentdb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Create DocumentDB parameter group
resource "aws_docdb_cluster_parameter_group" "main" {
  family = "docdb5.0"
  name   = "${var.cluster_identifier}-parameter-group"

  parameter {
    name  = "tls"
    value = "disabled" # For easier connection from bastion
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-parameter-group"
  })
}

# Create DocumentDB cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier = var.cluster_identifier
  engine             = "docdb"
  master_username    = var.master_username
  master_password    = var.master_password
  # backup_retention_period = 5
  # preferred_backup_window = "07:00-09:00"
  skip_final_snapshot = true

  db_subnet_group_name            = aws_docdb_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.documentdb.id]
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name

  storage_encrypted = true

  tags = merge(var.tags, {
    Name = var.cluster_identifier
  })

  # Ignore password changes after initial creation
  lifecycle {
    ignore_changes = [master_password]
  }
}

# Create DocumentDB cluster instances
resource "aws_docdb_cluster_instance" "main" {
  count              = var.instance_count
  identifier         = "${var.cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class

  tags = merge(var.tags, {
    Name = "${var.cluster_identifier}-${count.index + 1}"
  })
}
