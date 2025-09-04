// Configure a GCS backend; details (bucket/prefix) passed via -backend-config in init script
terraform {
  backend "gcs" {}
}
