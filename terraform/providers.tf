provider "aws" {
  region = var.aws_region
}

# ── NOTE: two-step apply required on first run ────────────────────────────────
# Step 1:  terraform apply -target=module.vpc -target=module.eks
# Step 2:  terraform apply
#
# Reason: the kubernetes and helm providers need the EKS cluster endpoint and
# CA cert to configure themselves. These values only exist after the cluster is
# created. The data sources below resolve them after step 1 so step 2 can
# deploy ArgoCD and the ALB controller cleanly.
# ─────────────────────────────────────────────────────────────────────────────

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
