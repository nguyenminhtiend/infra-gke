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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
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

# These will be configured once we have a GKE cluster
# provider "kubernetes" {
#   host                   = "https://${module.gke.endpoint}"
#   token                  = data.google_client_config.default.access_token
#   cluster_ca_certificate = base64decode(module.gke.ca_certificate)
# }

# provider "helm" {
#   kubernetes {
#     host                   = "https://${module.gke.endpoint}"
#     token                  = data.google_client_config.default.access_token
#     cluster_ca_certificate = base64decode(module.gke.ca_certificate)
#   }
# }

data "google_client_config" "default" {}

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
