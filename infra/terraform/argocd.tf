// Argo CD installation via Helm provider (pinned chart version)

locals {
  argocd_repo_url = "https://argoproj.github.io/argo-helm"
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/part-of"    = "argocd"
      "app.kubernetes.io/managed-by" = "terraform"
      env                             = "dev"
    }
  }
}

resource "helm_release" "argo_cd" {
  name       = "argo-cd"
  repository = local.argocd_repo_url
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  // Keep things minimal and Autopilot-friendly
  set {
    name  = "dex.enabled"
    value = "false"
  }

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  // Ensure Argo CD upgrades apply cleanly
  cleanup_on_fail  = true
  recreate_pods    = false
  atomic           = true
  dependency_update = true

  // Make sure the namespace exists before install
  depends_on = [kubernetes_namespace.argocd]
}

output "argocd_namespace" {
  value       = kubernetes_namespace.argocd.metadata[0].name
  description = "Namespace where Argo CD is installed"
}

