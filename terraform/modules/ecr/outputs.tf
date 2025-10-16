output "products_web_repository_url" {
  description = "URL of the products-web ECR repository"
  value       = aws_ecr_repository.products_web.repository_url
}

output "products_agent_repository_url" {
  description = "URL of the products-agent ECR repository"
  value       = aws_ecr_repository.products_agent.repository_url
}

output "products_mcp_repository_url" {
  description = "URL of the products-mcp ECR repository"
  value       = aws_ecr_repository.products_mcp.repository_url
}

output "products_web_repository_name" {
  description = "Name of the products-web ECR repository"
  value       = aws_ecr_repository.products_web.name
}

output "products_agent_repository_name" {
  description = "Name of the products-agent ECR repository"
  value       = aws_ecr_repository.products_agent.name
}

output "products_mcp_repository_name" {
  description = "Name of the products-mcp ECR repository"
  value       = aws_ecr_repository.products_mcp.name
}

output "ecr_registry_id" {
  description = "AWS account ID of the ECR registry"
  value       = aws_ecr_repository.products_web.registry_id
}

output "ecr_registry_url" {
  description = "Base URL of the ECR registry"
  value       = "${aws_ecr_repository.products_web.registry_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com"
}

data "aws_region" "current" {}
