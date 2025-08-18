# Project Information
output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

# Networking Outputs
output "vpc_network_name" {
  description = "VPC network name"
  value       = module.networking.vpc_network_name
}

output "gke_subnet_name" {
  description = "GKE subnet name"
  value       = module.networking.gke_subnet_name
}

output "static_ip_address" {
  description = "Static IP address for load balancer"
  value       = module.networking.main_ip_address
}

# GKE Outputs
output "cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = module.gke.cluster_location
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "app_namespace" {
  description = "Application namespace"
  value       = module.gke.app_namespace
}

# Artifact Registry Outputs
output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = module.artifact_registry.repository_url
}

# IAM Outputs
output "workload_identity_service_account" {
  description = "Workload Identity service account email"
  value       = module.iam.workload_identity_service_account_email
}

output "ci_cd_service_account" {
  description = "CI/CD service account email"
  value       = module.iam.ci_cd_service_account_email
}

output "workload_identity_provider" {
  description = "Workload Identity Pool Provider name"
  value       = module.iam.workload_identity_provider_name
}

# Connection Commands
output "kubectl_connection_command" {
  description = "Command to connect kubectl to the cluster"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}
