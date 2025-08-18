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
