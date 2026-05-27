output "vpc_id" {
  description = "ID of the custom VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs used by EKS nodes"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs used by NAT Gateway and ALB"
  value       = module.vpc.public_subnets
}

output "nat_public_ips" {
  description = "Elastic IP of the single NAT Gateway"
  value       = module.vpc.nat_public_ips
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "argocd_namespace" {
  value = module.argocd.namespace
}

output "alb_controller_iam_role_arn" {
  value = module.alb_controller.arn
}
