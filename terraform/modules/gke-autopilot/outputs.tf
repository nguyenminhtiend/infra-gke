# GKE Autopilot Module Outputs

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.autopilot.name
}

output "cluster_id" {
  description = "The ID of the GKE cluster"
  value       = google_container_cluster.autopilot.id
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.autopilot.location
}

output "cluster_endpoint" {
  description = "The IP address of the cluster master"
  value       = google_container_cluster.autopilot.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "The cluster ca certificate (base64 encoded)"
  value       = google_container_cluster.autopilot.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_version" {
  description = "The current version of the master in the cluster"
  value       = google_container_cluster.autopilot.master_version
}

output "services_ipv4_cidr" {
  description = "The IP address range of the Kubernetes services"
  value       = google_container_cluster.autopilot.services_ipv4_cidr
}

output "cluster_ipv4_cidr" {
  description = "The IP address range of the Kubernetes pods"
  value       = google_container_cluster.autopilot.cluster_ipv4_cidr
}

output "workload_identity_pool" {
  description = "The workload identity pool for the cluster"
  value       = "${var.project_id}.svc.id.goog"
}
