variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the bastion host"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name for the SSH key pair"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where bastion will be created"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet where bastion will be created"
  type        = string
}

variable "documentdb_sg_id" {
  description = "ID of the DocumentDB security group to allow access from bastion"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "vault_public_endpoint_url" {
  description = "The public endpoint URL of the Vault cluster"
  type        = string
}

variable "vault_admin_token" {
  description = "The admin token for the Vault cluster"
  type        = string
  sensitive   = true
}

variable "docdb_cluster_endpoint" {
  description = "DocumentDB cluster endpoint"
  type        = string
}

variable "docdb_username" {
  description = "DocumentDB username"
  type        = string
}

variable "docdb_password" {
  description = "DocumentDB password"
  type        = string
  sensitive   = true
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}
