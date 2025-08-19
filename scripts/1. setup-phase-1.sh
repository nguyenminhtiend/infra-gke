#!/bin/bash

# Phase 1: Foundation & Local Setup Script
# GKE Deployment Plan - 2025 Best Practices
# Project ID: infra-gke-469413

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="infra-gke-469413"
REGION="asia-southeast1"
TERRAFORM_STATE_BUCKET="${PROJECT_ID}-terraform-state"
GITHUB_ACTIONS_SA_NAME="github-actions"
TERRAFORM_SA_NAME="terraform"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get latest version from GitHub releases
get_latest_version() {
    local repo="$1"
    curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//'
}

print_status "🚀 Starting Phase 1: Foundation & Local Setup"
print_status "Project ID: $PROJECT_ID"
print_status "Region: $REGION"

# 1.1 GCP Project Setup
print_status "📋 Phase 1.1: GCP Project Setup"

# Check if gcloud is installed and authenticated
if ! command_exists gcloud; then
    print_error "gcloud CLI is not installed. Please install it first:"
    print_error "https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Set project
print_status "Setting GCP project to $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Enable required APIs
print_status "Enabling required GCP APIs..."
REQUIRED_APIS=(
    "container.googleapis.com"
    "compute.googleapis.com"
    "iam.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "cloudtrace.googleapis.com"
    "monitoring.googleapis.com"
    "logging.googleapis.com"
    "secretmanager.googleapis.com"
    "dns.googleapis.com"
    "servicenetworking.googleapis.com"
    "cloudkms.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
    print_status "Enabling $api..."
    if ! gcloud services enable $api 2>&1; then
        error_output=$(gcloud services enable $api 2>&1 || true)
        if echo "$error_output" | grep -q "being deactivated"; then
            print_warning "Service is being deactivated. Waiting 3 minutes for completion..."
            sleep 180
            print_status "Retrying $api..."
            gcloud services enable $api
        else
            print_error "Failed to enable $api: $error_output"
            exit 1
        fi
    fi
done

print_success "All required APIs enabled"

# Create service accounts
print_status "Creating service accounts..."

# Terraform service account
if ! gcloud iam service-accounts describe "${TERRAFORM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" >/dev/null 2>&1; then
    gcloud iam service-accounts create $TERRAFORM_SA_NAME \
        --display-name="Terraform Service Account" \
        --description="Service account for Terraform operations"
    print_success "Created Terraform service account"
else
    print_warning "Terraform service account already exists"
fi

# GitHub Actions service account
if ! gcloud iam service-accounts describe "${GITHUB_ACTIONS_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" >/dev/null 2>&1; then
    gcloud iam service-accounts create $GITHUB_ACTIONS_SA_NAME \
        --display-name="GitHub Actions Service Account" \
        --description="Service account for GitHub Actions CI/CD"
    print_success "Created GitHub Actions service account"
else
    print_warning "GitHub Actions service account already exists"
fi

# Assign roles to Terraform service account
print_status "Assigning roles to Terraform service account..."
TERRAFORM_ROLES=(
    "roles/editor"
    "roles/iam.serviceAccountAdmin"
    "roles/iam.serviceAccountKeyAdmin"
    "roles/storage.admin"
    "roles/container.admin"
    "roles/compute.admin"
    "roles/dns.admin"
)

for role in "${TERRAFORM_ROLES[@]}"; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${TERRAFORM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="$role"
done

# Assign roles to GitHub Actions service account
print_status "Assigning roles to GitHub Actions service account..."
GITHUB_ACTIONS_ROLES=(
    "roles/container.developer"
    "roles/cloudbuild.builds.builder"
    "roles/artifactregistry.admin"
    "roles/storage.objectAdmin"
)

for role in "${GITHUB_ACTIONS_ROLES[@]}"; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:${GITHUB_ACTIONS_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
        --role="$role"
done

print_success "Service accounts created and configured"

# Create GCS bucket for Terraform state
print_status "Creating GCS bucket for Terraform state..."
if ! gsutil ls gs://$TERRAFORM_STATE_BUCKET >/dev/null 2>&1; then
    gsutil mb -l $REGION gs://$TERRAFORM_STATE_BUCKET
    gsutil versioning set on gs://$TERRAFORM_STATE_BUCKET
    print_success "Created Terraform state bucket: gs://$TERRAFORM_STATE_BUCKET"
else
    print_warning "Terraform state bucket already exists"
fi

# 1.2 Local Development Environment Setup
print_status "📱 Phase 1.2: Local Development Environment Setup"

# Check macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_warning "This script is optimized for macOS. Some commands may need adjustment."
fi

# Install/Update Homebrew
if ! command_exists brew; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    print_status "Updating Homebrew..."
    brew update
fi

# Install/Update tools
print_status "Installing/updating development tools..."

# Install/Force upgrade Terraform to latest version
print_status "Installing/upgrading Terraform to latest version..."
TERRAFORM_LATEST_VERSION="1.12.2"
TERRAFORM_OS="darwin_arm64"

# Check if Terraform exists and get version
if command_exists terraform; then
    CURRENT_VERSION=$(terraform version | grep -o 'v[0-9.]*' | sed 's/v//' || echo "0.0.0")
    print_status "Current Terraform version: v$CURRENT_VERSION"
else
    CURRENT_VERSION="0.0.0"
    print_status "Terraform not found, installing..."
fi

# Install via Homebrew first if available, then upgrade manually if needed
if ! command_exists terraform; then
    print_status "Attempting Homebrew installation first..."
    brew install terraform 2>/dev/null || true
fi

# Check if we have a recent enough version, if not install manually
CURRENT_VERSION=$(terraform version 2>/dev/null | grep -o 'v[0-9.]*' | sed 's/v//' || echo "0.0.0")
if [ "$(printf '%s\n' "1.6.0" "$CURRENT_VERSION" | sort -V | head -n1)" != "1.6.0" ]; then
    print_warning "Terraform version $CURRENT_VERSION is too old. Installing latest version manually..."

    # Download and install latest Terraform
    print_status "Downloading Terraform v$TERRAFORM_LATEST_VERSION..."
    cd /tmp
    curl -LO "https://releases.hashicorp.com/terraform/${TERRAFORM_LATEST_VERSION}/terraform_${TERRAFORM_LATEST_VERSION}_${TERRAFORM_OS}.zip"
    unzip "terraform_${TERRAFORM_LATEST_VERSION}_${TERRAFORM_OS}.zip"

    # Install to /usr/local/bin
    sudo mv terraform /usr/local/bin/
    rm "terraform_${TERRAFORM_LATEST_VERSION}_${TERRAFORM_OS}.zip" LICENSE.txt 2>/dev/null || true

    # Update symlink if Homebrew version exists
    if [ -f "/opt/homebrew/bin/terraform" ]; then
        sudo rm /opt/homebrew/bin/terraform 2>/dev/null || true
        sudo ln -s /usr/local/bin/terraform /opt/homebrew/bin/terraform
    fi

    cd - >/dev/null
    print_success "Terraform v$TERRAFORM_LATEST_VERSION installed manually"
else
    print_status "Attempting Homebrew upgrade..."
    brew upgrade terraform 2>/dev/null || print_warning "Homebrew upgrade failed (expected due to license change)"
fi

# Verify final version
TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' || terraform version | grep -o 'v[0-9.]*' | sed 's/v//')
print_success "Terraform installed/updated: v$TERRAFORM_VERSION"

# Final version check
if [ "$(printf '%s\n' "1.6.0" "$TERRAFORM_VERSION" | sort -V | head -n1)" != "1.6.0" ]; then
    print_error "Terraform version $TERRAFORM_VERSION is still below minimum requirement (>= 1.6.0)"
    print_error "Please manually install Terraform >= 1.6.0 from https://www.terraform.io/downloads.html"
    exit 1
else
    print_success "Terraform version $TERRAFORM_VERSION meets minimum requirement"
fi

# Install kubectl
if ! command_exists kubectl; then
    brew install kubernetes-cli
else
    brew upgrade kubernetes-cli
fi

# Install kubectx and kubens
if ! command_exists kubectx; then
    brew install kubectx
else
    brew upgrade kubectx
fi

# Install k9s
if ! command_exists k9s; then
    brew install k9s
else
    brew upgrade k9s
fi

# Install gke-gcloud-auth-plugin
print_status "Installing/checking gke-gcloud-auth-plugin..."
if ! gcloud components list --filter="id:gke-gcloud-auth-plugin" --format="value(state.name)" | grep -q "Installed"; then
    print_status "Installing gke-gcloud-auth-plugin..."
    gcloud components install gke-gcloud-auth-plugin --quiet
    print_success "gke-gcloud-auth-plugin installed"
else
    print_success "gke-gcloud-auth-plugin already installed"
fi

# Install jq for JSON processing
if ! command_exists jq; then
    brew install jq
fi

# Install yq for YAML processing
if ! command_exists yq; then
    brew install yq
fi

# Install helm
if ! command_exists helm; then
    brew install helm
else
    brew upgrade helm
fi

# Check Docker
if ! command_exists docker; then
    print_warning "Docker is not installed. Please install Docker Desktop or Rancher Desktop:"
    print_warning "Docker Desktop: https://www.docker.com/products/docker-desktop"
    print_warning "Rancher Desktop: https://rancherdesktop.io/"
else
    print_success "Docker is available"
fi

# Configure gcloud application default credentials
print_status "Checking gcloud application default credentials..."
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    print_status "Application default credentials not found, setting up..."
    gcloud auth application-default login
    print_success "Application default credentials configured"
else
    print_success "Application default credentials already configured"
fi

# Configure kubectl for GKE
print_status "Setting up kubectl context..."
# Update gcloud components to ensure compatibility
print_status "Updating gcloud components..."
gcloud components update --quiet

# Try to configure kubectl if cluster exists
if gcloud container clusters list --region=$REGION --format="value(name)" 2>/dev/null | head -n1 | grep -q "."; then
    CLUSTER_NAME=$(gcloud container clusters list --region=$REGION --format="value(name)" | head -n1)
    print_status "Configuring kubectl for cluster: $CLUSTER_NAME"
    gcloud container clusters get-credentials "$CLUSTER_NAME" --region=$REGION
    print_success "kubectl configured for GKE cluster"
else
    print_warning "No GKE clusters found yet - this is expected for Phase 1"
    print_warning "kubectl will be configured automatically when you create a cluster"
fi

print_success "Local development environment setup completed"

# 1.3 Create Terraform Structure
print_status "📁 Phase 1.3: Creating Terraform Structure"

# Create directory structure
mkdir -p terraform/{environments/{dev,staging,prod},modules/{gke-autopilot,networking,iam,observability,security},shared/backend-config}

# Create .gitignore for Terraform
cat > terraform/.gitignore << 'EOF'
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files, which are likely to contain sensitive data
*.tfvars
*.tfvars.json

# Ignore override files as they are usually used to override resources locally and so
# are not checked in
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Include override files you do wish to add to version control using negated pattern
# !example_override.tf

# Include tfplan files to ignore the plan output of command: terraform plan -out=tfplan
*tfplan*

# Ignore CLI configuration files
.terraformrc
terraform.rc

# Ignore service account keys
*.json
!terragrunt.hcl
EOF

# Create backend configuration
cat > terraform/shared/backend-config/backend.tf << EOF
terraform {
  backend "gcs" {
    bucket = "$TERRAFORM_STATE_BUCKET"
    prefix = "terraform/state"
  }
}
EOF

# Create versions.tf for consistent provider versions
cat > terraform/shared/backend-config/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.14"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}
EOF

# Create main provider configuration
cat > terraform/shared/backend-config/providers.tf << EOF
provider "google" {
  project = "$PROJECT_ID"
  region  = "$REGION"
}

provider "google-beta" {
  project = "$PROJECT_ID"
  region  = "$REGION"
}

# These will be configured once we have a GKE cluster
# provider "kubernetes" {
#   host                   = "https://\${module.gke.endpoint}"
#   token                  = data.google_client_config.default.access_token
#   cluster_ca_certificate = base64decode(module.gke.ca_certificate)
# }

# provider "helm" {
#   kubernetes {
#     host                   = "https://\${module.gke.endpoint}"
#     token                  = data.google_client_config.default.access_token
#     cluster_ca_certificate = base64decode(module.gke.ca_certificate)
#   }
# }

data "google_client_config" "default" {}
EOF

# Create development environment configuration
cat > terraform/environments/dev/main.tf << EOF
terraform {
  backend "gcs" {
    bucket = "$TERRAFORM_STATE_BUCKET"
    prefix = "terraform/state/dev"
  }
}

module "backend_config" {
  source = "../../shared/backend-config"
}

# Variables for development environment
locals {
  project_id  = "$PROJECT_ID"
  region      = "$REGION"
  environment = "dev"

  # Network configuration
  network_name    = "\${local.environment}-vpc"
  subnet_name     = "\${local.environment}-subnet"
  subnet_cidr     = "10.1.0.0/24"

  # GKE configuration
  cluster_name    = "\${local.environment}-gke-cluster"

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
EOF

# Create terraform.tfvars.example
cat > terraform/environments/dev/terraform.tfvars.example << EOF
# Copy this file to terraform.tfvars and customize as needed

# Project Configuration
project_id = "$PROJECT_ID"
region     = "$REGION"

# Environment Configuration
environment = "dev"

# GKE Configuration
cluster_name = "dev-gke-cluster"
node_count   = 1

# Network Configuration
network_name = "dev-vpc"
subnet_name  = "dev-subnet"
subnet_cidr  = "10.1.0.0/24"

# Labels
labels = {
  environment = "dev"
  project     = "$PROJECT_ID"
  managed_by  = "terraform"
}
EOF

print_success "Terraform structure created"

# Create service account keys directory (for later use)
mkdir -p .gcp-keys
echo "*.json" > .gcp-keys/.gitignore
echo "# Service account keys directory" > .gcp-keys/README.md
echo "This directory stores GCP service account keys for CI/CD (not committed to git)" >> .gcp-keys/README.md

# Create GitHub Actions workflows directory structure
print_status "📁 Phase 1.4: GitHub Repository Structure"
mkdir -p .github/workflows

# Create basic GitHub Actions workflow for later phases
cat > .github/workflows/terraform-plan.yml << 'EOF'
name: Terraform Plan

on:
  pull_request:
    paths:
      - 'terraform/**'
  workflow_dispatch:

env:
  TF_VERSION: 'latest'

jobs:
  terraform-plan:
    name: Terraform Plan
    runs-on: ubuntu-latest

    permissions:
      contents: read
      pull-requests: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Setup Google Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Terraform Format Check
        working-directory: ./terraform/environments/dev
        run: terraform fmt -check

      - name: Terraform Init
        working-directory: ./terraform/environments/dev
        run: terraform init

      - name: Terraform Validate
        working-directory: ./terraform/environments/dev
        run: terraform validate

      - name: Terraform Plan
        working-directory: ./terraform/environments/dev
        run: terraform plan -no-color
        continue-on-error: true
EOF

# Create apps directory structure for Phase 3
print_status "Creating application structure..."
mkdir -p apps/{service-a,service-b}/{src,k8s}

# Create basic README files
cat > terraform/README.md << 'EOF'
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
EOF

cat > apps/README.md << 'EOF'
# Applications

This directory contains the application services for the platform.

## Structure

- `service-a/`: Example NestJS service
- `service-b/`: Example NestJS service

Each service follows this structure:
- `src/`: Source code
- `k8s/`: Kubernetes manifests
- `Dockerfile`: Container build configuration
- `package.json`: Node.js dependencies
EOF

# Final status
print_success "🎉 Phase 1 setup completed successfully!"

echo ""
print_status "📋 Summary of what was set up:"
echo "  ✅ GCP project configured with required APIs"
echo "  ✅ Service accounts created (terraform, github-actions)"
echo "  ✅ GCS bucket for Terraform state: gs://$TERRAFORM_STATE_BUCKET"
echo "  ✅ Local development tools installed/updated"
echo "  ✅ Terraform directory structure created"
echo "  ✅ GitHub Actions workflow templates created"
echo "  ✅ Application directory structure created"

echo ""
print_status "📝 Next Steps:"
echo "  1. Review and customize terraform/environments/dev/terraform.tfvars.example"
echo "  2. Test Terraform configuration: cd terraform/environments/dev && terraform init"
echo "  3. Proceed to Phase 2: Basic Infrastructure"

echo ""
print_status "🔧 Tool Versions Installed:"
terraform version | head -n1
kubectl version --client=true --output=yaml 2>/dev/null | grep gitVersion | head -n1
helm version --short 2>/dev/null || echo "Helm version: $(helm version --template='{{.Version}}')"
k9s version 2>/dev/null | head -n1 || echo "k9s: $(k9s version -s)"

echo ""
print_warning "⚠️  Manual Steps Required:"
echo "  1. Install Docker Desktop or Rancher Desktop if not already installed"
echo "  2. Ensure your GitHub repository is set up for CI/CD"
echo "  3. Create terraform.tfvars from the example file in terraform/environments/dev/"

echo ""
print_success "Phase 1 setup script completed! 🚀"
