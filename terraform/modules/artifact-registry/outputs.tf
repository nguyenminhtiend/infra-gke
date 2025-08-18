# Artifact Registry Module Outputs

output "repository_name" {
  description = "The name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.repo.name
}

output "repository_id" {
  description = "The ID of the Artifact Registry repository"
  value       = google_artifact_registry_repository.repo.repository_id
}

output "repository_url" {
  description = "The URL of the repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
}

output "docker_config_command" {
  description = "Command to configure Docker authentication"
  value       = "gcloud auth configure-docker ${var.region}-docker.pkg.dev"
}
