# Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "docker_repo" {
  repository_id = var.repository_name
  location      = var.region
  format        = "DOCKER"
  description   = "Docker repository for ${var.environment} environment"

  labels = {
    environment = var.environment
    managed-by  = "terraform"
  }

  # Cleanup policies
  cleanup_policies {
    id     = "delete-old-images"
    action = "DELETE"
    
    condition {
      tag_state  = "TAGGED"
      older_than = "${var.retention_days}d"
    }
  }

  cleanup_policies {
    id     = "keep-recent-images"
    action = "KEEP"
    
    most_recent_versions {
      keep_count = var.keep_count
    }
  }
}

# IAM binding for Docker repository
resource "google_artifact_registry_repository_iam_binding" "docker_repo_readers" {
  project    = var.project_id
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.reader"
  
  members = [
    "serviceAccount:${var.gke_service_account}",
    "serviceAccount:${var.ci_service_account}",
  ]
}

resource "google_artifact_registry_repository_iam_binding" "docker_repo_writers" {
  project    = var.project_id
  location   = google_artifact_registry_repository.docker_repo.location
  repository = google_artifact_registry_repository.docker_repo.name
  role       = "roles/artifactregistry.writer"
  
  members = [
    "serviceAccount:${var.ci_service_account}",
  ]
}

# Binary Authorization policy
resource "google_binary_authorization_policy" "policy" {
  admission_whitelist_patterns {
    name_pattern = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}/*"
  }

  # Default rule - require attestation
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"

    require_attestations_by = [
      google_binary_authorization_attestor.build_attestor.name
    ]
  }

  # Global evaluation mode
  global_policy_evaluation_mode = "ENABLE"
}

# Attestor for build verification
resource "google_binary_authorization_attestor" "build_attestor" {
  name = "${var.environment}-build-attestor"
  description = "Build attestor for ${var.environment}"

  attestation_authority_note {
    note_reference = google_container_analysis_note.build_note.name

    public_keys {
      ascii_armored_pgp_public_key = var.pgp_public_key
      id = "build-key"
    }
  }
}

# Container Analysis note for attestation
resource "google_container_analysis_note" "build_note" {
  name = "${var.environment}-build-note"
  
  attestation_authority {
    hint {
      human_readable_name = "Build verification for ${var.environment}"
    }
  }
}
