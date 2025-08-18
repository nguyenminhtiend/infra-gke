# Workload Identity service account for GKE workloads
resource "google_service_account" "workload_identity" {
  account_id   = var.workload_identity_sa_name
  display_name = "Workload Identity Service Account for ${var.environment}"
  description  = "Service account for GKE workloads using Workload Identity"
}

# CI/CD service account for GitHub Actions
resource "google_service_account" "ci_cd" {
  account_id   = var.ci_cd_sa_name
  display_name = "CI/CD Service Account for ${var.environment}"
  description  = "Service account for CI/CD operations"
}

# GKE service account for node operations
resource "google_service_account" "gke_nodes" {
  account_id   = var.gke_nodes_sa_name
  display_name = "GKE Nodes Service Account for ${var.environment}"
  description  = "Service account for GKE nodes"
}

# IAM bindings for Workload Identity service account
resource "google_project_iam_binding" "workload_identity_bindings" {
  for_each = toset(var.workload_identity_roles)

  project = var.project_id
  role    = each.value
  members = [
    "serviceAccount:${google_service_account.workload_identity.email}"
  ]
}

# IAM bindings for CI/CD service account
resource "google_project_iam_binding" "ci_cd_bindings" {
  for_each = toset(var.ci_cd_roles)

  project = var.project_id
  role    = each.value
  members = [
    "serviceAccount:${google_service_account.ci_cd.email}"
  ]
}

# IAM bindings for GKE nodes service account
resource "google_project_iam_binding" "gke_nodes_bindings" {
  for_each = toset(var.gke_nodes_roles)

  project = var.project_id
  role    = each.value
  members = [
    "serviceAccount:${google_service_account.gke_nodes.email}"
  ]
}

# Workload Identity binding
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.workload_identity.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account}]"
  ]
}

# Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = var.github_pool_id
  display_name              = "GitHub Actions Pool for ${var.environment}"
  description               = "Workload Identity Pool for GitHub Actions"
}

# Workload Identity Pool Provider for GitHub
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = var.github_provider_id
  display_name                       = "GitHub Provider for ${var.environment}"
  description                        = "Workload Identity Pool Provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Bind GitHub Actions to CI/CD service account
resource "google_service_account_iam_binding" "github_actions_binding" {
  service_account_id = google_service_account.ci_cd.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/attribute.repository/${var.github_repository}"
  ]
}

# KMS key for encryption
resource "google_kms_key_ring" "key_ring" {
  name     = "${var.environment}-key-ring"
  location = var.region
}

resource "google_kms_crypto_key" "gke_key" {
  name     = "${var.environment}-gke-key"
  key_ring = google_kms_key_ring.key_ring.id

  purpose = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

# KMS key IAM binding for GKE
resource "google_kms_crypto_key_iam_binding" "gke_key_binding" {
  crypto_key_id = google_kms_crypto_key.gke_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-${data.google_project.project.number}@container-engine-robot.iam.gserviceaccount.com"
  ]
}

# Data source for project information
data "google_project" "project" {
  project_id = var.project_id
}
