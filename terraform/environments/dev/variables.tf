variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-southeast1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "gke-autopilot-dev"
}

variable "vpc_name" {
  description = "VPC network name"
  type        = string
  default     = "gke-vpc-dev"
}

variable "github_repository" {
  description = "GitHub repository for Workload Identity (format: owner/repo)"
  type        = string
  default     = "tien-nguyen-engineer/gke-app"
}
