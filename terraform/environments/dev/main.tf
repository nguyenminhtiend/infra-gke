terraform {
  backend "gcs" {
    bucket = "infra-gke-469413-terraform-state"
    prefix = "terraform/state/dev"
  }
}

module "backend_config" {
  source = "../../shared/backend-config"
}

# Variables for development environment
locals {
  project_id  = "infra-gke-469413"
  region      = "asia-southeast1"
  environment = "dev"

  # Network configuration
  network_name    = "${local.environment}-vpc"
  subnet_name     = "${local.environment}-subnet"
  subnet_cidr     = "10.1.0.0/24"

  # GKE configuration
  cluster_name    = "${local.environment}-gke-cluster"

  common_labels = {
    environment = local.environment
    project     = local.project_id
    managed_by  = "terraform"
  }
}

# This will be uncommented in Phase 2 when we create the networking module
# module "networking" {
#   source = "../../modules/networking"
#
#   project_id   = local.project_id
#   region       = local.region
#   network_name = local.network_name
#   subnet_name  = local.subnet_name
#   subnet_cidr  = local.subnet_cidr
#   labels       = local.common_labels
# }
