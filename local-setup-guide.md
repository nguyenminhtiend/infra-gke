# Local Setup Guide - macOS to GCP with Terraform

## Prerequisites

- macOS (Intel or Apple Silicon)
- GCP Account with billing enabled
- GCP Project created
- Admin access to the GCP project

---

## Step 1: Install Required Tools

### 1.1 Install Homebrew (if not installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 1.2 Install Google Cloud CLI

```bash
# Install gcloud CLI
brew install --cask google-cloud-sdk

# Or for Apple Silicon specifically
arch -arm64 brew install --cask google-cloud-sdk
```

### 1.3 Install Terraform

```bash
# Install latest Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify installation
terraform version
```

### 1.4 Install Kubernetes Tools

```bash
# kubectl for Kubernetes management
brew install kubectl

# kubectx for context switching
brew install kubectx

# k9s for Kubernetes CLI UI
brew install k9s

# Helm for package management
brew install helm
```

### 1.5 Install Additional Tools

```bash
# jq for JSON processing
brew install jq

# yq for YAML processing
brew install yq

# stern for multi-pod logging
brew install stern

# ArgoCD CLI
brew install argocd
```

---

## Step 2: Configure GCP Authentication

### 2.1 Initialize gcloud

```bash
# Login to GCP
gcloud auth login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Set default region
gcloud config set compute/region asia-southeast1
gcloud config set compute/zone asia-southeast1-a
```

### 2.2 Create Service Account for Terraform

```bash
# Set variables
export PROJECT_ID=$(gcloud config get-value project)
export SA_NAME="terraform-sa"

# Create service account
gcloud iam service-accounts create ${SA_NAME} \
    --display-name="Terraform Service Account" \
    --description="Service account for Terraform operations"

# Grant necessary roles
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/container.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/resourcemanager.projectIamAdmin"
```

### 2.3 Create and Download Service Account Key

```bash
# Create key file
gcloud iam service-accounts keys create ~/terraform-gcp-key.json \
    --iam-account=${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=~/terraform-gcp-key.json

# Add to shell profile for persistence
echo 'export GOOGLE_APPLICATION_CREDENTIALS=~/terraform-gcp-key.json' >> ~/.zshrc
source ~/.zshrc
```

---

## Step 3: Enable Required GCP APIs

```bash
# Enable essential APIs
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable cloudtrace.googleapis.com
gcloud services enable clouderrorreporting.googleapis.com
gcloud services enable cloudprofiler.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable networkmanagement.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable certificatemanager.googleapis.com
```

---

## Step 4: Setup Terraform Backend

### 4.1 Create GCS Bucket for Terraform State

```bash
# Set bucket name (must be globally unique)
export BUCKET_NAME="${PROJECT_ID}-terraform-state"

# Create bucket in Singapore region
gsutil mb -p ${PROJECT_ID} -l asia-southeast1 gs://${BUCKET_NAME}/

# Enable versioning
gsutil versioning set on gs://${BUCKET_NAME}/

# Enable uniform bucket-level access
gsutil iam ch allUsers:objectViewer gs://${BUCKET_NAME}
```

### 4.2 Create Terraform Backend Configuration

```bash
# Create terraform directory structure
mkdir -p terraform/environments/dev
cd terraform/environments/dev

# Create backend.tf
cat > backend.tf << EOF
terraform {
  backend "gcs" {
    bucket = "${BUCKET_NAME}"
    prefix = "terraform/state/dev"
  }
}
EOF
```

---

## Step 5: Initialize Terraform Project

### 5.1 Create Provider Configuration

```bash
# Create versions.tf
cat > versions.tf << 'EOF'
terraform {
  required_version = ">= 1.9.0"

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
      version = "~> 2.35"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}
EOF
```

### 5.2 Create Provider Configuration

```bash
# Create providers.tf
cat > providers.tf << EOF
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
EOF
```

### 5.3 Create Variables File

```bash
# Create variables.tf
cat > variables.tf << 'EOF'
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
EOF
```

### 5.4 Create terraform.tfvars

```bash
# Create terraform.tfvars with your values
cat > terraform.tfvars << EOF
project_id = "${PROJECT_ID}"
region     = "asia-southeast1"
environment = "dev"
EOF
```

### 5.5 Initialize Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format files
terraform fmt -recursive
```

---

## Step 6: Test Connection

### 6.1 Create Test Resource

```bash
# Create main.tf with a simple test resource
cat > main.tf << 'EOF'
# Test resource - Create a GCS bucket
resource "google_storage_bucket" "test_bucket" {
  name          = "${var.project_id}-test-bucket-${var.environment}"
  location      = var.region
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }
}

output "bucket_url" {
  value = google_storage_bucket.test_bucket.url
}
EOF
```

### 6.2 Plan and Apply

```bash
# Create execution plan
terraform plan

# Apply changes
terraform apply

# Verify bucket creation
gsutil ls

# Clean up test resources
terraform destroy
```

---

## Step 7: Setup GitHub Secrets (for CI/CD)

### 7.1 Create GitHub Service Account

```bash
# Create service account for GitHub Actions
export GITHUB_SA_NAME="github-actions-sa"

gcloud iam service-accounts create ${GITHUB_SA_NAME} \
    --display-name="GitHub Actions Service Account"

# Grant necessary roles
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${GITHUB_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/container.developer"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${GITHUB_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.writer"
```

### 7.2 Create Workload Identity Pool (Recommended)

```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
    --location="global" \
    --display-name="GitHub Actions Pool"

# Create provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
    --location="global" \
    --workload-identity-pool="github-pool" \
    --display-name="GitHub Provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --issuer-uri="https://token.actions.githubusercontent.com"
```

---

## Step 8: Directory Structure Setup

```bash
# Create complete project structure
mkdir -p ~/Projects/gke-app/{terraform,apps,scripts,.github/workflows}
cd ~/Projects/gke-app

# Create .gitignore
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars
*.auto.tfvars

# Node
node_modules/
dist/
.env
*.log

# IDE
.vscode/
.idea/
*.swp
.DS_Store

# Keys
*.json
*.pem
*.key
EOF
```

---

## Troubleshooting

### Common Issues and Solutions

1. **Authentication Issues**

```bash
# Re-authenticate
gcloud auth application-default login
```

2. **API Not Enabled**

```bash
# Check enabled APIs
gcloud services list --enabled

# Enable specific API
gcloud services enable SERVICE_NAME.googleapis.com
```

3. **Terraform State Lock**

```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

4. **Permission Denied**

```bash
# Check current identity
gcloud auth list

# Check project
gcloud config get-value project
```

---

## Security Best Practices

1. **Never commit credentials**

   - Add \*.json to .gitignore
   - Use environment variables

2. **Use Workload Identity**

   - Preferred over service account keys
   - More secure for production

3. **Rotate Keys Regularly**

```bash
# List existing keys
gcloud iam service-accounts keys list \
    --iam-account=${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

# Delete old keys
gcloud iam service-accounts keys delete KEY_ID \
    --iam-account=${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
```

4. **Use Least Privilege**
   - Grant minimal required permissions
   - Use custom roles when needed

---

## Next Steps

1. Create Terraform modules for GKE cluster
2. Set up GitHub repository with Actions
3. Deploy sample NestJS applications
4. Configure ArgoCD for GitOps
5. Implement monitoring and logging

---

## Useful Commands Reference

```bash
# GCP Commands
gcloud config list                    # Show current configuration
gcloud projects list                  # List all projects
gcloud compute regions list           # List available regions
gcloud container clusters list        # List GKE clusters

# Terraform Commands
terraform init                        # Initialize Terraform
terraform plan                        # Preview changes
terraform apply                       # Apply changes
terraform destroy                     # Destroy resources
terraform state list                  # List resources in state
terraform output                      # Show outputs

# Kubectl Commands
kubectl config current-context        # Show current context
kubectl get nodes                     # List cluster nodes
kubectl get pods --all-namespaces    # List all pods
kubectl describe pod POD_NAME        # Describe pod

# Troubleshooting
gcloud auth list                      # List authenticated accounts
terraform console                     # Interactive console
kubectl logs POD_NAME -f             # Follow pod logs
```
