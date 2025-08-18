terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }

  backend "gcs" {
    bucket = "infra-gke-469413-terraform-state"
    prefix = "terraform/state/dev"
  }
}

provider "google" {
  project = "infra-gke-469413"
  region  = "asia-southeast1"
}

provider "google-beta" {
  project = "infra-gke-469413"
  region  = "asia-southeast1"
}

# Variables for development environment
locals {
  project_id  = "infra-gke-469413"
  region      = "asia-southeast1"
  environment = "dev"

  # Network configuration
  network_name = "${local.environment}-vpc"
  subnet_name  = "${local.environment}-subnet"
  subnet_cidr  = "10.1.0.0/24"

  # GKE configuration
  cluster_name = "${local.environment}-gke-cluster"

  common_labels = {
    environment = local.environment
    project     = local.project_id
    managed_by  = "terraform"
  }
}

# Outputs
output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gke.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "network_name" {
  description = "Name of the VPC network"
  value       = module.networking.network_name
}

output "artifact_registry_url" {
  description = "Artifact Registry repository URL"
  value       = module.artifact_registry.repository_url
}

# Phase 2: Basic Infrastructure Modules

# Networking module
module "networking" {
  source = "../../modules/networking"

  project_id   = local.project_id
  region       = local.region
  network_name = local.network_name
  subnet_name  = local.subnet_name
  subnet_cidr  = local.subnet_cidr
  labels       = local.common_labels
}

# GKE Autopilot cluster
module "gke" {
  source     = "../../modules/gke-autopilot"
  depends_on = [module.networking]

  project_id                    = local.project_id
  region                        = local.region
  cluster_name                  = local.cluster_name
  network_self_link             = module.networking.network_self_link
  subnet_self_link              = module.networking.subnet_self_link
  pods_secondary_range_name     = module.networking.pods_secondary_range_name
  services_secondary_range_name = module.networking.services_secondary_range_name
  labels                        = local.common_labels
}

# Artifact Registry
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id      = local.project_id
  region          = local.region
  repository_name = "${local.environment}-container-images"
  description     = "Container images for ${local.environment} environment"
  labels          = local.common_labels
}
