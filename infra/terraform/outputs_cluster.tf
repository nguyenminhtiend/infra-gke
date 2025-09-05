output "cluster_name" {
  value       = google_container_cluster.autopilot.name
  description = "GKE Autopilot cluster name"
}

output "cluster_location" {
  value       = google_container_cluster.autopilot.location
  description = "Location (region) of the GKE cluster"
}

output "cluster_endpoint" {
  value       = google_container_cluster.autopilot.endpoint
  description = "Endpoint of the GKE cluster"
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate
  description = "Cluster CA certificate"
  sensitive   = true
}

