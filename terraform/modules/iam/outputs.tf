output "workload_identity_service_account_email" {
  description = "Workload Identity service account email"
  value       = google_service_account.workload_identity.email
}

output "ci_cd_service_account_email" {
  description = "CI/CD service account email"
  value       = google_service_account.ci_cd.email
}

output "gke_nodes_service_account_email" {
  description = "GKE nodes service account email"
  value       = google_service_account.gke_nodes.email
}

output "workload_identity_pool_name" {
  description = "Workload Identity Pool name"
  value       = google_iam_workload_identity_pool.github_pool.name
}

output "workload_identity_provider_name" {
  description = "Workload Identity Pool Provider name"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "kms_key_id" {
  description = "KMS key ID for GKE encryption"
  value       = google_kms_crypto_key.gke_key.id
}

output "kms_key_ring_name" {
  description = "KMS key ring name"
  value       = google_kms_key_ring.key_ring.name
}
