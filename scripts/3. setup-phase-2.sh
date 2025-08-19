#!/bin/bash

# Phase 2: Basic Infrastructure Setup Script
# GKE Deployment Plan - 2025 Best Practices
# Creates networking, GKE Autopilot cluster, and Artifact Registry

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
ENVIRONMENT="dev"
TERRAFORM_DIR="terraform/environments/dev"

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

print_status "🚀 Starting Phase 2: Basic Infrastructure Setup"
print_status "Project ID: $PROJECT_ID"
print_status "Region: $REGION"
print_status "Environment: $ENVIRONMENT"

echo ""
print_status "📋 Phase 2 will create:"
echo "  • VPC network with subnets and firewall rules"
echo "  • GKE Autopilot cluster with latest features"
echo "  • Artifact Registry for container images"
echo "  • IAM permissions for CI/CD"

# Validate prerequisites
print_status "🔍 Validating prerequisites..."

# Check if gcloud is installed and authenticated
if ! command_exists gcloud; then
    print_error "gcloud CLI is not installed"
    exit 1
fi

# Check if terraform is installed
if ! command_exists terraform; then
    print_error "Terraform is not installed"
    exit 1
fi

# Check if we're in the right directory
if [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Terraform directory not found: $TERRAFORM_DIR"
    print_error "Please run this script from the project root"
    exit 1
fi

# Check if project is set correctly
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    print_error "Current GCP project ($CURRENT_PROJECT) doesn't match expected project ($PROJECT_ID)"
    print_error "Run: gcloud config set project $PROJECT_ID"
    exit 1
fi

print_success "Prerequisites validated"

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

# Test access to the GCS bucket for Terraform state
TERRAFORM_STATE_BUCKET="${PROJECT_ID}-terraform-state"
print_status "Testing access to Terraform state bucket..."
if ! gsutil ls "gs://$TERRAFORM_STATE_BUCKET" >/dev/null 2>&1; then
    print_error "Cannot access Terraform state bucket: gs://$TERRAFORM_STATE_BUCKET"
    print_error "Please ensure the bucket exists and you have proper permissions"
    exit 1
fi

print_success "Authentication validated"

# Check for GOOGLE_APPLICATION_CREDENTIALS in shell profiles to prevent future issues
print_status "Checking shell profiles for GOOGLE_APPLICATION_CREDENTIALS..."
SHELL_PROFILES=(
    "$HOME/.zshrc"
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.profile"
)

for profile in "${SHELL_PROFILES[@]}"; do
    if [ -f "$profile" ] && grep -q "GOOGLE_APPLICATION_CREDENTIALS.*terraform-gcp-key.json" "$profile" 2>/dev/null; then
        print_warning "Found GOOGLE_APPLICATION_CREDENTIALS in $profile"
        print_warning "Consider removing or commenting out this line to avoid conflicts:"
        grep -n "GOOGLE_APPLICATION_CREDENTIALS.*terraform-gcp-key.json" "$profile" | head -1
        echo ""
    fi
done

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

# Check if terraform.tfvars exists, if not create from example
if [ ! -f "terraform.tfvars" ]; then
    if [ -f "terraform.tfvars.example" ]; then
        print_status "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars
        print_success "Created terraform.tfvars - please review and customize if needed"
    else
        print_error "terraform.tfvars.example not found"
        exit 1
    fi
fi

# Initialize Terraform
print_status "🔧 Initializing Terraform..."
terraform init

# Validate Terraform configuration
print_status "🔍 Validating Terraform configuration..."
terraform validate

# Format Terraform files
print_status "🎨 Formatting Terraform files..."
terraform fmt -recursive

# Plan infrastructure changes
print_status "📋 Planning infrastructure changes..."
terraform plan -out=tfplan

# Show what will be created
echo ""
print_status "📊 Infrastructure Summary:"
echo "The following resources will be created:"
echo ""

# Extract resource counts from plan
terraform show -json tfplan | jq -r '
.resource_changes[] |
select(.change.actions[] == "create") |
.type' | sort | uniq -c | while read count type; do
    echo "  • $count x $type"
done

echo ""
read -p "Do you want to proceed with creating this infrastructure? (y/N): " confirm

if [[ $confirm =~ ^[Yy]$ ]]; then
    print_status "🚀 Applying infrastructure changes..."

    # Apply the changes
    terraform apply tfplan

    print_success "Infrastructure deployment completed!"

    # Clean up plan file
    rm -f tfplan

    # Ensure kubectl authentication is properly configured
    ensure_kubectl_auth() {
        print_status "Ensuring kubectl authentication is properly configured..."

        # Check and install gke-gcloud-auth-plugin if needed
        if ! gcloud components list --filter="id:gke-gcloud-auth-plugin" --format="value(state.name)" | grep -q "Installed"; then
            print_status "Installing gke-gcloud-auth-plugin..."
            gcloud components install gke-gcloud-auth-plugin --quiet
            print_success "gke-gcloud-auth-plugin installed"
        else
            print_success "gke-gcloud-auth-plugin already installed"
        fi

        # Update gcloud components
        print_status "Updating gcloud components for compatibility..."
        gcloud components update --quiet
    }

    ensure_kubectl_auth

    # Get cluster credentials
    print_status "🔑 Configuring kubectl access to the cluster..."
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    gcloud container clusters get-credentials "$CLUSTER_NAME" --region "$REGION" --project "$PROJECT_ID"

    print_success "kubectl configured for cluster: $CLUSTER_NAME"

    # Configure Docker for Artifact Registry
    print_status "🐳 Configuring Docker for Artifact Registry..."
    gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

    print_success "Docker configured for Artifact Registry"

    # Test cluster connectivity
    print_status "🧪 Testing cluster connectivity..."
    if kubectl cluster-info >/dev/null 2>&1; then
        print_success "Cluster is accessible via kubectl"

        # Show cluster information
        echo ""
        print_status "📊 Cluster Information:"
        echo "  Cluster Name: $(terraform output -raw cluster_name)"
        echo "  Network: $(terraform output -raw network_name)"
        echo "  Registry: $(terraform output -raw artifact_registry_url)"
        echo ""

        # Show nodes (should be empty for Autopilot initially)
        print_status "📋 Cluster Nodes (will auto-provision when workloads are deployed):"
        kubectl get nodes 2>/dev/null || echo "  No nodes yet - Autopilot will create them on demand"

    else
        print_warning "Cluster is not immediately accessible - this is normal, may take a few minutes"
    fi

else
    print_warning "Infrastructure deployment cancelled"
    rm -f tfplan
    exit 0
fi

# Return to project root
cd - >/dev/null

echo ""
print_success "🎉 Phase 2 setup completed successfully!"

echo ""
print_status "📋 What was created:"
echo "  ✅ VPC network with custom subnets"
echo "  ✅ GKE Autopilot cluster (latest stable version)"
echo "  ✅ Artifact Registry repository"
echo "  ✅ Firewall rules for cluster communication"
echo "  ✅ Cloud NAT for outbound connectivity"
echo "  ✅ IAM permissions for GitHub Actions"

echo ""
print_status "📝 Next Steps:"
echo "  1. Run the validation script: ./scripts/4.\\ validate-phase-2.sh"
echo "  2. Test cluster access: kubectl get namespaces"
echo "  3. Proceed to Phase 3: Application Setup"

echo ""
print_status "🔧 Useful Commands:"
echo "  • kubectl config current-context    # Check current cluster context"
echo "  • kubectl get nodes                 # List cluster nodes (auto-created on demand)"
echo "  • gcloud container clusters list    # List all clusters"
echo "  • terraform -chdir=$TERRAFORM_DIR output  # Show infrastructure outputs"

echo ""
print_success "Phase 2 setup script completed! 🚀"
