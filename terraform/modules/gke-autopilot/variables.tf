variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the cluster"
  type        = string
}

variable "vpc_network_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "gke_subnet_name" {
  description = "Name of the GKE subnet"
  type        = string
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the master nodes"
  type        = string
  default     = "172.16.0.0/28"
}

variable "release_channel" {
  description = "Release channel for GKE cluster"
  type        = string
  default     = "STABLE"
  
  validation {
    condition = contains([
      "RAPID",
      "REGULAR", 
      "STABLE"
    ], var.release_channel)
    error_message = "Release channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_name" {
  description = "KMS key name for database encryption"
  type        = string
  default     = null
}

variable "maintenance_start_time" {
  description = "Maintenance window start time"
  type        = string
  default     = "2024-01-01T02:00:00Z"
}

variable "maintenance_end_time" {
  description = "Maintenance window end time"
  type        = string
  default     = "2024-01-01T06:00:00Z"
}

variable "app_namespace" {
  description = "Kubernetes namespace for applications"
  type        = string
  default     = "applications"
}

variable "k8s_service_account_name" {
  description = "Kubernetes service account name"
  type        = string
  default     = "workload-identity-sa"
}

variable "workload_identity_service_account" {
  description = "GCP service account for Workload Identity"
  type        = string
}
