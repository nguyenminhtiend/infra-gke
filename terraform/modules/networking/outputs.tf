output "vpc_network" {
  description = "VPC network"
  value       = google_compute_network.vpc_network
}

output "gke_subnet" {
  description = "GKE subnet"
  value       = google_compute_subnetwork.gke_subnet
}

output "main_ip_address" {
  description = "Static IP address for load balancer"
  value       = google_compute_global_address.main_ip.address
}

output "main_ip_name" {
  description = "Name of the static IP address"
  value       = google_compute_global_address.main_ip.name
}

output "vpc_network_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc_network.name
}

output "gke_subnet_name" {
  description = "GKE subnet name"
  value       = google_compute_subnetwork.gke_subnet.name
}
