# Self-signed TLS certificate for ALB
resource "tls_private_key" "alb_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Second certificate that includes the ALB DNS name (created after ALB)
resource "tls_self_signed_cert" "alb_cert_with_dns" {
  private_key_pem = tls_private_key.alb_private_key.private_key_pem

  subject {
    common_name = "products-web.hashidemo.com"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = [
    "products-web.hashidemo.com",
    "products-web.local",
    "*.elb.amazonaws.com",
    aws_lb.main.dns_name,
  ]

  ip_addresses = [
    aws_instance.bastion.public_ip,
  ]

  depends_on = [aws_lb.main]
}


resource "aws_acm_certificate" "alb_cert_with_dns" {
  private_key      = tls_private_key.alb_private_key.private_key_pem
  certificate_body = tls_self_signed_cert.alb_cert_with_dns.cert_pem

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-certificate"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security group rule to allow ALB to access bastion on port 8080
resource "aws_security_group_rule" "bastion_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.bastion.id
  description              = "HTTP access from ALB on port 8080"
}

# Target group for bastion host
resource "aws_lb_target_group" "bastion_tg" {
  name     = "${var.name_prefix}-bastion-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 10
    unhealthy_threshold = 5
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-tg"
  })
}

# Attach bastion instance to target group
resource "aws_lb_target_group_attachment" "bastion_attachment" {
  target_group_arn = aws_lb_target_group.bastion_tg.arn
  target_id        = aws_instance.bastion.id
  port             = 8080
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# HTTPS Listener for ALB
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.alb_cert_with_dns.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bastion_tg.arn
  }
}

# HTTP Listener for ALB (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# IAM policy for ECR access
data "aws_iam_policy_document" "ecr_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_policy" {
  name        = "${var.name_prefix}-ecr-access"
  description = "Policy to allow ECR access for pulling Docker images"
  policy      = data.aws_iam_policy_document.ecr_policy.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecr-policy"
  })
}

# IAM policy for Bedrock access
data "aws_iam_policy_document" "bedrock_policy" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModels"
    ]
    resources = [
      "arn:aws:bedrock:eu-central-1:${var.aws_account_id}:inference-profile/eu.amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-west-3:${var.aws_account_id}:inference-profile/eu.amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-west-1:${var.aws_account_id}:inference-profile/eu.amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-north-1:${var.aws_account_id}:inference-profile/eu.amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-west-3::foundation-model/amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-west-1::foundation-model/amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-central-1::foundation-model/amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-north-1::foundation-model/amazon.nova-pro-v1:0",
      "arn:aws:bedrock:eu-central-1::foundation-model/amazon.nova-lite-v1:0",
      "arn:aws:bedrock:eu-central-1::foundation-model/amazon.nova-micro-v1:0",
      "arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-3-5-sonnet-20240620-v1:0",
      "arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
      "arn:aws:bedrock:eu-central-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
    ]
  }
}

resource "aws_iam_policy" "bedrock_policy" {
  name        = "${var.name_prefix}-bedrock-access"
  description = "Policy to allow invoking Bedrock models"
  policy      = data.aws_iam_policy_document.bedrock_policy.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bedrock-policy"
  })
}

# IAM role for bastion host
resource "aws_iam_role" "bastion_role" {
  name = "${var.name_prefix}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-role"
  })
}

# Attach ECR policy to bastion role
resource "aws_iam_role_policy_attachment" "bastion_ecr_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.ecr_policy.arn
}

# Attach Bedrock policy to bastion role
resource "aws_iam_role_policy_attachment" "bastion_bedrock_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.bedrock_policy.arn
}

# Instance profile for bastion host
resource "aws_iam_instance_profile" "bastion_profile" {
  name = "${var.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion_role.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-profile"
  })
}