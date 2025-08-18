variable "repository_name" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "apps"
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "retention_days" {
  description = "Number of days to retain images"
  type        = number
  default     = 30
}

variable "keep_count" {
  description = "Number of recent images to keep"
  type        = number
  default     = 10
}

variable "gke_service_account" {
  description = "GKE service account email for image pulling"
  type        = string
}

variable "ci_service_account" {
  description = "CI/CD service account email for image pushing"
  type        = string
}

variable "pgp_public_key" {
  description = "PGP public key for binary authorization"
  type        = string
  default     = ""
}
