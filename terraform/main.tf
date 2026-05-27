data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  vpc_name        = var.vpc_name
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  cluster_name    = var.cluster_name
}

# ── EKS ───────────────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  instance_type      = var.instance_type_eks
  min_nodes          = var.min_nodes
  max_nodes          = var.max_nodes
  desired_size       = var.desired_size

  # Nodes go into private subnets; control plane uses both
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  depends_on = [module.vpc]
}

# ── ALB Controller ────────────────────────────────────────────────────────────
module "alb_controller" {
  source = "./modules/alb_controller"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id

  depends_on = [module.eks]
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────
module "argocd" {
  source = "./modules/argocd"

  depends_on = [module.alb_controller]
}
