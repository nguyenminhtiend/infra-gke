# IAM Module
module "iam" {
  source = "../../modules/iam"
  
  project_id        = var.project_id
  environment       = var.environment
  region            = var.region
  github_repository = var.github_repository
}

# Networking Module
module "networking" {
  source = "../../modules/networking"
  
  vpc_name = var.vpc_name
  region   = var.region
}

# Artifact Registry Module
module "artifact_registry" {
  source = "../../modules/artifact-registry"
  
  project_id            = var.project_id
  region                = var.region
  environment           = var.environment
  gke_service_account   = module.iam.gke_nodes_service_account_email
  ci_service_account    = module.iam.ci_cd_service_account_email
}

# GKE Autopilot Module
module "gke" {
  source = "../../modules/gke-autopilot"
  
  cluster_name                      = var.cluster_name
  project_id                        = var.project_id
  region                            = var.region
  vpc_network_name                  = module.networking.vpc_network_name
  gke_subnet_name                   = module.networking.gke_subnet_name
  environment                       = var.environment
  kms_key_name                      = module.iam.kms_key_id
  workload_identity_service_account = module.iam.workload_identity_service_account_email
  
  depends_on = [
    module.networking,
    module.iam
  ]
}

# Configure kubectl context
resource "null_resource" "configure_kubectl" {
  depends_on = [module.gke]
  
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
  }
  
  triggers = {
    cluster_name = module.gke.cluster_name
  }
}
