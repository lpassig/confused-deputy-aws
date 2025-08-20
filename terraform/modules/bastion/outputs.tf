output "instance_id" {
  description = "ID of the bastion instance"
  value       = aws_instance.bastion.id
}

output "public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "private_ip" {
  description = "Private IP address of the bastion host"
  value       = aws_instance.bastion.private_ip
}

output "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  value       = local_file.private_key.filename
}

output "security_group_id" {
  description = "ID of the bastion security group"
  value       = aws_security_group.bastion.id
}

output "key_pair_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.main.key_name
}

# Vault JWT Auth outputs
output "jwt_auth_accessor" {
  description = "Accessor of the JWT auth backend"
  value       = vault_jwt_auth_backend.jwt.accessor
}

output "jwt_auth_path" {
  description = "Path of the JWT auth backend"
  value       = vault_jwt_auth_backend.jwt.path
}

output "readonly_group_id" {
  description = "ID of the readonly identity group"
  value       = vault_identity_group.readonly.id
}

output "readwrite_group_id" {
  description = "ID of the readwrite identity group"
  value       = vault_identity_group.readwrite.id
}
