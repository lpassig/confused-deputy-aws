variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "cluster_identifier" {
  description = "The cluster identifier for DocumentDB"
  type        = string
}

variable "master_username" {
  description = "Username for the DocumentDB master user"
  type        = string
}

variable "master_password" {
  description = "Password for the DocumentDB master user"
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "The compute and memory capacity of the DocumentDB instance"
  type        = string
  default     = "db.t3.medium"
}

variable "instance_count" {
  description = "Number of DocumentDB instances in the cluster"
  type        = number
  default     = 1
}

variable "vpc_id" {
  description = "ID of the VPC where DocumentDB will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for DocumentDB"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access DocumentDB"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
