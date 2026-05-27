resource "aws_iam_policy" "policy" {
  name_prefix = "${var.cluster_name}-alb-policy-"
  policy      = file("${path.module}/iam_policy.json")
}

module "role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.6.0"

  name = "${var.cluster_name}-alb-role"

  policies = {
    alb_policy = aws_iam_policy.policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "kubernetes_service_account_v1" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.role.arn
    }
  }
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "3.3.0"

  timeout = 600
  atomic  = true

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account_v1.alb_controller.metadata[0].name
    },
    {
      name  = "replicaCount"
      value = "1"
    },
  ]

  depends_on = [kubernetes_service_account_v1.alb_controller]
}
