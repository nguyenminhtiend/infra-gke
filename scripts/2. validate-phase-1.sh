#!/bin/bash

# Phase 1 Validation Script
# Validates that Phase 1 setup was completed successfully

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID="infra-gke-469413"
REGION="asia-southeast1"
TERRAFORM_STATE_BUCKET="${PROJECT_ID}-terraform-state"

print_status() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "🔍 Phase 1 Validation - Checking Setup Completeness"
echo "=================================================="

# Check GCP project and APIs
# Check and fix authentication issues
print_status "🔐 Validating authentication..."

# Check if GOOGLE_APPLICATION_CREDENTIALS is set to wrong project
if [ ! -z "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
    print_warning "GOOGLE_APPLICATION_CREDENTIALS is set to: $GOOGLE_APPLICATION_CREDENTIALS"

    # Try to extract project from the credentials file if it's JSON
    if [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
        CRED_PROJECT=$(jq -r '.project_id // empty' "$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null || echo "")
        if [ ! -z "$CRED_PROJECT" ] && [ "$CRED_PROJECT" != "$PROJECT_ID" ]; then
            print_error "Service account credentials are for project '$CRED_PROJECT' but we need '$PROJECT_ID'"
            print_status "Unsetting GOOGLE_APPLICATION_CREDENTIALS to use application default credentials..."
            unset GOOGLE_APPLICATION_CREDENTIALS
            export GOOGLE_APPLICATION_CREDENTIALS=""
            print_success "GOOGLE_APPLICATION_CREDENTIALS unset"
        elif [ -z "$CRED_PROJECT" ]; then
            print_warning "Could not determine project from credentials file"
            print_status "Unsetting GOOGLE_APPLICATION_CREDENTIALS to avoid conflicts..."
            unset GOOGLE_APPLICATION_CREDENTIALS
            export GOOGLE_APPLICATION_CREDENTIALS=""
            print_success "GOOGLE_APPLICATION_CREDENTIALS unset"
        fi
    else
        print_warning "Credentials file does not exist, unsetting GOOGLE_APPLICATION_CREDENTIALS..."
        unset GOOGLE_APPLICATION_CREDENTIALS
        export GOOGLE_APPLICATION_CREDENTIALS=""
        print_success "GOOGLE_APPLICATION_CREDENTIALS unset"
    fi
fi

# Verify application default credentials work for the current project
print_status "Verifying application default credentials..."
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    print_warning "Application default credentials not configured or expired"
    print_status "Setting up application default credentials..."
    gcloud auth application-default login
fi

print_success "Authentication validated"

print_status "Validating GCP project setup..."
if gcloud config get-value project | grep -q "$PROJECT_ID"; then
    print_success "GCP project is set to $PROJECT_ID"
else
    print_error "GCP project is not set to $PROJECT_ID"
fi

# Check enabled APIs
print_status "Checking enabled APIs..."
REQUIRED_APIS=(
    "container.googleapis.com"
    "compute.googleapis.com"
    "iam.googleapis.com"
    "cloudbuild.googleapis.com"
    "artifactregistry.googleapis.com"
)

for api in "${REQUIRED_APIS[@]}"; do
    if gcloud services list --enabled --filter="name:$api" --format="value(name)" | grep -q "$api"; then
        print_success "$api is enabled"
    else
        print_error "$api is not enabled"
    fi
done

# Check service accounts
print_status "Checking service accounts..."
if gcloud iam service-accounts describe "terraform@${PROJECT_ID}.iam.gserviceaccount.com" >/dev/null 2>&1; then
    print_success "Terraform service account exists"
else
    print_error "Terraform service account not found"
fi

if gcloud iam service-accounts describe "github-actions@${PROJECT_ID}.iam.gserviceaccount.com" >/dev/null 2>&1; then
    print_success "GitHub Actions service account exists"
else
    print_error "GitHub Actions service account not found"
fi

# Check GCS bucket
print_status "Checking Terraform state bucket..."
if gsutil ls gs://$TERRAFORM_STATE_BUCKET >/dev/null 2>&1; then
    print_success "Terraform state bucket exists: gs://$TERRAFORM_STATE_BUCKET"
else
    print_error "Terraform state bucket not found"
fi

# Check local tools
print_status "Validating local development tools..."

tools=(
    "gcloud:Google Cloud SDK"
    "terraform:Terraform"
    "kubectl:Kubernetes CLI"
    "kubectx:Kubernetes Context Switcher"
    "k9s:Kubernetes TUI"
    "helm:Helm"
    "docker:Docker"
    "jq:JSON Processor"
    "yq:YAML Processor"
)

for tool_info in "${tools[@]}"; do
    tool=${tool_info%%:*}
    description=${tool_info##*:}

    if command_exists "$tool"; then
        if [ "$tool" = "terraform" ]; then
            # Special handling for Terraform version validation
            version_output=$($tool version 2>/dev/null | head -n1 || echo "unknown")
            print_success "$description is installed: $version_output"

            # Check if Terraform version meets minimum requirement (1.6.0)
            tf_version=$(echo "$version_output" | grep -o 'v[0-9.]*' | sed 's/v//' || echo "0.0.0")
            required_version="1.6.0"

            # Simple version comparison (works for x.y.z format)
            if [ "$(printf '%s\n' "$required_version" "$tf_version" | sort -V | head -n1)" = "$required_version" ]; then
                print_success "Terraform version $tf_version meets minimum requirement (>= $required_version)"
            else
                print_error "Terraform version $tf_version is below minimum requirement (>= $required_version)"
                print_status "Please run the setup script to upgrade Terraform"
            fi
        else
            version=$($tool version 2>/dev/null | head -n1 || echo "installed")
            print_success "$description is installed: $version"
        fi
    else
        print_error "$description is not installed"
    fi
done

# Check directory structure
print_status "Validating directory structure..."

directories=(
    "terraform"
    "terraform/environments/dev"
    "terraform/environments/staging"
    "terraform/environments/prod"
    "terraform/modules"
    "terraform/shared/backend-config"
    "apps"
    ".github/workflows"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        print_success "Directory exists: $dir"
    else
        print_error "Directory missing: $dir"
    fi
done

# Check key files
print_status "Validating key configuration files..."

files=(
    "terraform/shared/backend-config/backend.tf"
    "terraform/shared/backend-config/versions.tf"
    "terraform/shared/backend-config/providers.tf"
    "terraform/environments/dev/main.tf"
    "terraform/environments/dev/terraform.tfvars.example"
    ".github/workflows/terraform-plan.yml"
    "terraform/.gitignore"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        print_success "File exists: $file"
    else
        print_error "File missing: $file"
    fi
done

# Check Terraform initialization capability
print_status "Testing Terraform initialization..."
cd terraform/environments/dev
if terraform init -backend=false >/dev/null 2>&1; then
    print_success "Terraform configuration is valid"
else
    print_error "Terraform configuration has issues"
fi
cd - >/dev/null

echo ""
echo "🎯 Phase 1 Validation Summary"
echo "=============================="
echo ""
echo "If all checks show ✓, Phase 1 is complete and you can proceed to Phase 2."
echo "If any checks show ✗, please review and fix the issues before continuing."
echo ""
echo "Next steps:"
echo "1. Copy terraform/environments/dev/terraform.tfvars.example to terraform.tfvars"
echo "2. Customize the terraform.tfvars file as needed"
echo "3. Run: cd terraform/environments/dev && terraform init"
echo "4. Proceed to Phase 2: Basic Infrastructure setup"
echo ""
print_status "🔧 Recommended Tool Versions:"
echo "  - Terraform: >= 1.6.0 (latest is 1.12.x)"
echo "  - Google Cloud SDK: latest"
echo "  - kubectl: latest"
