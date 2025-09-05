// GKE Autopilot cluster (regional) with Workload Identity and labels

variable "cluster_name" {
  type        = string
  description = "Name of the GKE Autopilot cluster"
  default     = "dev-autopilot"
}

variable "cluster_resource_labels" {
  type        = map(string)
  description = "Resource labels to apply to the cluster"
  default = {
    env = "dev"
  }
}

resource "google_container_cluster" "autopilot" {
  name     = var.cluster_name
  location = var.region

  enable_autopilot = true

  release_channel {
    channel = "STABLE"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  resource_labels = var.cluster_resource_labels
}

