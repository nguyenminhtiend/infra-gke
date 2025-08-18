variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "workload_identity_sa_name" {
  description = "Workload Identity service account name"
  type        = string
  default     = "workload-identity-sa"
}

variable "ci_cd_sa_name" {
  description = "CI/CD service account name"
  type        = string
  default     = "ci-cd-sa"
}

variable "gke_nodes_sa_name" {
  description = "GKE nodes service account name"
  type        = string
  default     = "gke-nodes-sa"
}

variable "workload_identity_roles" {
  description = "IAM roles for Workload Identity service account"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/cloudtrace.agent",
    "roles/clouderrorreporting.writer"
  ]
}

variable "ci_cd_roles" {
  description = "IAM roles for CI/CD service account"
  type        = list(string)
  default = [
    "roles/artifactregistry.writer",
    "roles/container.developer",
    "roles/cloudbuild.builds.builder",
    "roles/storage.objectAdmin"
  ]
}

variable "gke_nodes_roles" {
  description = "IAM roles for GKE nodes service account"
  type        = list(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader"
  ]
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for Workload Identity binding"
  type        = string
  default     = "applications"
}

variable "k8s_service_account" {
  description = "Kubernetes service account for Workload Identity binding"
  type        = string
  default     = "workload-identity-sa"
}

variable "github_pool_id" {
  description = "GitHub Workload Identity Pool ID"
  type        = string
  default     = "github-pool"
}

variable "github_provider_id" {
  description = "GitHub Workload Identity Pool Provider ID"
  type        = string
  default     = "github-provider"
}

variable "github_repository" {
  description = "GitHub repository for Workload Identity (format: owner/repo)"
  type        = string
}
