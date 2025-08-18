output "repository_name" {
  description = "Artifact Registry repository name"
  value       = google_artifact_registry_repository.docker_repo.name
}

output "repository_url" {
  description = "Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

output "repository_id" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.docker_repo.repository_id
}

output "binary_authorization_policy" {
  description = "Binary Authorization policy name"
  value       = google_binary_authorization_policy.policy.id
}

output "build_attestor_name" {
  description = "Build attestor name"
  value       = google_binary_authorization_attestor.build_attestor.name
}
