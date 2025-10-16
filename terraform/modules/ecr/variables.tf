variable "name_prefix" {
  description = "Prefix for ECR repository names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to ECR repositories"
  type        = map(string)
  default     = {}
}
