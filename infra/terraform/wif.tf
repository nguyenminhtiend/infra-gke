// Workload Identity Federation for GitHub Actions -> GCP SA impersonation

variable "wif_pool_id" {
  type        = string
  description = "ID of the Workload Identity Pool (short name)"
  default     = "gh-pool"
}

variable "wif_provider_id" {
  type        = string
  description = "ID of the Workload Identity Provider in the pool (short name)"
  default     = "gh-provider"
}

variable "github_org" {
  type        = string
  description = "GitHub organization/owner name"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "github_allowed_ref" {
  type        = string
  description = "Allowed Git ref for CI (e.g., refs/heads/main)"
  default     = "refs/heads/main"
}

data "google_project" "current" {}

resource "google_iam_workload_identity_pool" "gh_pool" {
  project                   = var.project_id
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub OIDC Pool"
  description               = "OIDC pool for GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "gh_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.gh_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id
  display_name                       = "GitHub OIDC Provider"
  description                        = "Trust GitHub Actions OIDC tokens"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
  // Restrict to a single repo and ref for safety
  attribute_condition = "attribute.repository == '${var.github_org}/${var.github_repo}' && attribute.ref == '${var.github_allowed_ref}'"
}

// Service Account used by GitHub Actions via WIF
resource "google_service_account" "tf_ci" {
  project      = var.project_id
  account_id   = "terraform-ci"
  display_name = "Terraform CI via WIF"
}

// Allow principals from the WIF provider to impersonate the SA
resource "google_service_account_iam_binding" "wif_impersonation" {
  service_account_id = google_service_account.tf_ci.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gh_pool.name}/attribute.repository/${var.github_org}/${var.github_repo}"
  ]
}

// Project-level roles for the CI SA (keep minimal for learning)
// Enough to create and manage a GKE cluster using default VPC
resource "google_project_iam_member" "ci_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.tf_ci.email}"
}

resource "google_project_iam_member" "ci_compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "serviceAccount:${google_service_account.tf_ci.email}"
}

output "wif_pool_name" {
  value       = google_iam_workload_identity_pool.gh_pool.name
  description = "Full name of the WIF pool"
}

output "wif_provider_name" {
  value       = google_iam_workload_identity_pool_provider.gh_provider.name
  description = "Full name of the WIF provider"
}

output "ci_service_account_email" {
  value       = google_service_account.tf_ci.email
  description = "Service Account email for CI"
}
