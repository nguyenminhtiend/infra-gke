variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Default region for regional resources"
}

variable "argocd_namespace" {
  type        = string
  description = "Namespace where Argo CD is installed"
  default     = "argocd"
}

variable "argocd_chart_version" {
  type        = string
  description = "Pinned Helm chart version for argo-cd (from argo-helm repo)"
}
