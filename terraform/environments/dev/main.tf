# Test resource - Create a GCS bucket for validation
resource "google_storage_bucket" "test_bucket" {
  name          = "${var.project_id}-test-bucket-${var.environment}"
  location      = var.region
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }
}

output "bucket_url" {
  description = "URL of the test bucket"
  value       = google_storage_bucket.test_bucket.url
}

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}
