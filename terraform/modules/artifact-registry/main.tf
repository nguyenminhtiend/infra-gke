# Artifact Registry Module
# Creates Docker repository for container images

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "repository_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "container-images"
}

variable "description" {
  description = "Description of the repository"
  type        = string
  default     = "Docker repository for container images"
}

variable "labels" {
  description = "Labels to apply to the repository"
  type        = map(string)
  default     = {}
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.repository_name
  description   = var.description
  format        = "DOCKER"
  project       = var.project_id

  # Cleanup policies for cost optimization
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"

    condition {
      older_than = "7d"
      tag_state  = "UNTAGGED"
    }
  }

  labels = var.labels
}

# IAM binding for the GitHub Actions service account to push images
resource "google_artifact_registry_repository_iam_member" "github_actions_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.repo.location
  repository = google_artifact_registry_repository.repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:github-actions@${var.project_id}.iam.gserviceaccount.com"
}

# IAM binding for the GKE service account to pull images
resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.repo.location
  repository = google_artifact_registry_repository.repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
}

# Configure Docker authentication for local development
resource "null_resource" "configure_docker_auth" {
  depends_on = [google_artifact_registry_repository.repo]

  provisioner "local-exec" {
    command = "gcloud auth configure-docker ${var.region}-docker.pkg.dev --quiet"
  }

  triggers = {
    repository_name = google_artifact_registry_repository.repo.name
  }
}
