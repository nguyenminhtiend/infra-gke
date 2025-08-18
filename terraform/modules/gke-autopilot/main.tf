# GKE Autopilot Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # Use Autopilot mode
  enable_autopilot = true

  # Network configuration
  network    = var.vpc_network_name
  subnetwork = var.gke_subnet_name

  # IP allocation for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Master authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks"
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel
  release_channel {
    channel = var.release_channel
  }

  # Addons (simplified for Autopilot)
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  # Binary authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Security and compliance features (managed by Autopilot)

  # Database encryption
  database_encryption {
    state    = "ENCRYPTED"
    key_name = var.kms_key_name
  }

  # Monitoring and logging
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER"
    ]

    managed_prometheus {
      enabled = true
    }

    advanced_datapath_observability_config {
      enable_metrics = true
      enable_relay   = true
    }
  }

  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "CONTROLLER_MANAGER",
      "SCHEDULER"
    ]
  }

  # Security configuration
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Maintenance policy
  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = "FREQ=WEEKLY;BYDAY=SA"
    }
  }

  # Resource labels
  resource_labels = {
    environment = var.environment
    managed-by  = "terraform"
    project     = var.project_id
  }

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      node_pool,
      initial_node_count,
    ]
  }
}

# Node pool will be automatically managed by Autopilot
# No need to define node pools explicitly

# Create a namespace for the application
resource "kubernetes_namespace" "applications" {
  depends_on = [google_container_cluster.primary]

  metadata {
    name = var.app_namespace

    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }

    annotations = {
      "iam.gke.io/gcp-service-account" = var.workload_identity_service_account
    }
  }
}

# Service account for Kubernetes
resource "kubernetes_service_account" "workload_identity" {
  depends_on = [google_container_cluster.primary]

  metadata {
    name      = var.k8s_service_account_name
    namespace = kubernetes_namespace.applications.metadata[0].name

    annotations = {
      "iam.gke.io/gcp-service-account" = var.workload_identity_service_account
    }
  }
}
