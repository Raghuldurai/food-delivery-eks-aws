output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs — pass to EKS node groups"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs — pass to ALB / ingress"
  value       = module.vpc.public_subnets
}

output "nat_public_ips" {
  description = "Elastic IP of the single NAT Gateway"
  value       = module.vpc.nat_public_ips
}
