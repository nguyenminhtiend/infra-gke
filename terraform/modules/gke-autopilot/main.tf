# GKE Autopilot Module
# Creates a GKE Autopilot cluster with 2025 best practices

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "network_self_link" {
  description = "The self-link of the VPC network"
  type        = string
}

variable "subnet_self_link" {
  description = "The self-link of the subnet"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "The name of the secondary range for pods"
  type        = string
}

variable "services_secondary_range_name" {
  description = "The name of the secondary range for services"
  type        = string
}

variable "labels" {
  description = "Labels to apply to the cluster"
  type        = map(string)
  default     = {}
}

# Data source for latest GKE version
data "google_container_engine_versions" "gke_version" {
  location = var.region
  project  = var.project_id
}

# GKE Autopilot Cluster
resource "google_container_cluster" "autopilot" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Autopilot mode
  enable_autopilot = true

  # Network configuration
  network    = var.network_self_link
  subnetwork = var.subnet_self_link

  # IP allocation policy for secondary ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  # Latest GKE version on stable channel
  min_master_version = data.google_container_engine_versions.gke_version.latest_master_version
  release_channel {
    channel = "STABLE"
  }

  # Security and operational configurations
  # Note: cluster_security_group is not available in Autopilot mode

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Network policy is automatically enabled in Autopilot
  # network_policy is not configurable in Autopilot mode

  # Logging and monitoring configuration (GKE 1.29+)
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER"
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "DEPLOYMENT",
      "STATEFULSET",
      "DAEMONSET",
      "HPA",
      "POD"
    ]

    # Managed Prometheus
    managed_prometheus {
      enabled = true
    }

    # Advanced datapath observability
    advanced_datapath_observability_config {
      enable_metrics = true
      enable_relay   = true
    }
  }

  # Binary Authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Cluster features
  # Note: cluster_features is not needed as enable_autopilot = true handles this

  # Notification configuration
  notification_config {
    pubsub {
      enabled = false
    }
  }

  # Security posture
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Node pool configuration is fully managed by Autopilot
  # remove_default_node_pool and initial_node_count are not configurable in Autopilot

  # Timeouts
  timeouts {
    create = "30m"
    update = "40m"
    delete = "30m"
  }

  # Labels
  resource_labels = var.labels

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      # Ignore changes to node version as it's managed by GKE
      min_master_version,
    ]
  }
}

# Get cluster credentials for kubectl
resource "null_resource" "get_credentials" {
  depends_on = [google_container_cluster.autopilot]

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"
  }

  triggers = {
    cluster_name = google_container_cluster.autopilot.name
  }
}
