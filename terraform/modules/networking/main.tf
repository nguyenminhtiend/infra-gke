# VPC Network
resource "google_compute_network" "vpc_network" {
  name                    = var.vpc_name
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode           = "REGIONAL"
}

# Subnet for GKE cluster
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "${var.vpc_name}-gke-subnet"
  ip_cidr_range = var.gke_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id

  # Secondary ranges for GKE pods and services
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.gke_services_cidr
  }

  # Enable private Google access
  private_ip_google_access = true
}

# Cloud Router for Cloud NAT
resource "google_compute_router" "nat_router" {
  name    = "${var.vpc_name}-nat-router"
  region  = var.region
  network = google_compute_network.vpc_network.id
}

# Cloud NAT for outbound internet access
resource "google_compute_router_nat" "nat_gateway" {
  name                               = "${var.vpc_name}-nat-gateway"
  router                            = google_compute_router.nat_router.name
  region                            = var.region
  nat_ip_allocate_option           = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rule to allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.vpc_name}-allow-internal"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [
    var.gke_subnet_cidr,
    var.gke_pods_cidr,
    var.gke_services_cidr
  ]
}

# Firewall rule for SSH access (if needed)
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.vpc_name}-allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # Google Cloud Console IP range
  target_tags   = ["ssh-allowed"]
}

# Firewall rule for health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${var.vpc_name}-allow-health-checks"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  target_tags = ["gke-node"]
}

# Static IP for load balancer
resource "google_compute_global_address" "main_ip" {
  name = "${var.vpc_name}-main-ip"
}

# Private Service Connect for Google APIs
resource "google_compute_global_address" "private_service_connect" {
  name          = "${var.vpc_name}-psc-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_service_connect" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_connect.name]
}
