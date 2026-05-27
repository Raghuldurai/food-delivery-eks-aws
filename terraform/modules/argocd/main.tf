resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  chart            = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  namespace        = kubernetes_namespace_v1.argocd.metadata[0].name
  create_namespace = false
  version          = "9.5.15"

  timeout = 600
  atomic  = true

  set = [
    {
      name  = "server.service.type"
      value = "ClusterIP"
    },
  ]

  depends_on = [kubernetes_namespace_v1.argocd]
}
