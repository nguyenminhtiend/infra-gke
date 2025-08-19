# Terraform Infrastructure

This directory contains the Terraform configuration for the GKE infrastructure.

## Structure

- `environments/`: Environment-specific configurations (dev, staging, prod)
- `modules/`: Reusable Terraform modules
- `shared/`: Shared configurations like backend and provider settings

## Usage

1. Navigate to the desired environment: `cd environments/dev`
2. Initialize Terraform: `terraform init`
3. Plan changes: `terraform plan`
4. Apply changes: `terraform apply`

## Prerequisites

- Terraform >= 1.9.0
- Google Cloud SDK
- Appropriate GCP service account credentials
