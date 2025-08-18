output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = google_container_cluster.primary.location
}

output "cluster_id" {
  description = "GKE cluster ID"
  value       = google_container_cluster.primary.id
}

output "app_namespace" {
  description = "Application namespace"
  value       = kubernetes_namespace.applications.metadata[0].name
}

output "k8s_service_account_name" {
  description = "Kubernetes service account name"
  value       = kubernetes_service_account.workload_identity.metadata[0].name
}
