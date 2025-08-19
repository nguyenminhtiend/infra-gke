#!/bin/bash

# Destroy Phase 1: Foundation & Local Setup
# Destroys service accounts, GCS state bucket, and optionally disables APIs

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
TERRAFORM_SA_NAME="terraform"
GITHUB_ACTIONS_SA_NAME="github-actions"

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

print_status "🗑️ Starting Phase 1 Destroy: Foundation & Local Setup"
print_status "Project ID: $PROJECT_ID"
print_status "Region: $REGION"

echo ""
print_warning "⚠️ This will destroy:"
echo "  • Service accounts (terraform, github-actions)"
echo "  • GCS bucket for Terraform state (and all state files)"
echo "  • IAM policy bindings for service accounts"
echo "  • Local Terraform configurations and artifacts"
echo "  • Optionally: GCP APIs (if you choose)"

echo ""
read -p "Are you sure you want to destroy Phase 1 foundation? (type 'yes' to confirm): " confirm

if [[ "$confirm" != "yes" ]]; then
    print_warning "Destroy cancelled"
    exit 0
fi

# Validate prerequisites
print_status "🔍 Validating prerequisites..."

# Check if gcloud is installed
if ! command_exists gcloud; then
    print_error "gcloud CLI is not installed"
    exit 1
fi

# Check if project is set correctly
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)
if [ "$CURRENT_PROJECT" != "$PROJECT_ID" ]; then
    print_error "Current GCP project ($CURRENT_PROJECT) doesn't match expected project ($PROJECT_ID)"
    print_error "Run: gcloud config set project $PROJECT_ID"
    exit 1
fi

# Check authentication
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    print_error "Application default credentials not configured"
    print_error "Run: gcloud auth application-default login"
    exit 1
fi

print_success "Prerequisites validated"

# === PHASE 1: IAM CLEANUP ===
print_status "🧹 Removing IAM policy bindings..."

# Roles to remove from terraform service account
TERRAFORM_ROLES=(
    "roles/editor"
    "roles/iam.serviceAccountAdmin"
    "roles/iam.serviceAccountKeyAdmin"
    "roles/storage.admin"
    "roles/container.admin"
    "roles/compute.admin"
    "roles/dns.admin"
)

# Roles to remove from github-actions service account
GITHUB_ACTIONS_ROLES=(
    "roles/container.developer"
    "roles/cloudbuild.builds.builder"
    "roles/artifactregistry.admin"
    "roles/storage.objectAdmin"
)

# Remove roles from Terraform service account
TERRAFORM_SA_EMAIL="${TERRAFORM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$TERRAFORM_SA_EMAIL" >/dev/null 2>&1; then
    print_status "Removing IAM roles from Terraform service account..."
    for role in "${TERRAFORM_ROLES[@]}"; do
        gcloud projects remove-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$TERRAFORM_SA_EMAIL" \
            --role="$role" --quiet 2>/dev/null || true
    done
fi

# Remove roles from GitHub Actions service account
GITHUB_ACTIONS_SA_EMAIL="${GITHUB_ACTIONS_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$GITHUB_ACTIONS_SA_EMAIL" >/dev/null 2>&1; then
    print_status "Removing IAM roles from GitHub Actions service account..."
    for role in "${GITHUB_ACTIONS_ROLES[@]}"; do
        gcloud projects remove-iam-policy-binding $PROJECT_ID \
            --member="serviceAccount:$GITHUB_ACTIONS_SA_EMAIL" \
            --role="$role" --quiet 2>/dev/null || true
    done
fi

print_success "IAM policy bindings removed"

# === PHASE 2: SERVICE ACCOUNTS ===
print_status "🗑️ Deleting service accounts..."

# Delete Terraform service account
if gcloud iam service-accounts describe "$TERRAFORM_SA_EMAIL" >/dev/null 2>&1; then
    print_status "Deleting Terraform service account..."
    gcloud iam service-accounts delete "$TERRAFORM_SA_EMAIL" --quiet
    print_success "Terraform service account deleted"
else
    print_warning "Terraform service account not found"
fi

# Delete GitHub Actions service account
if gcloud iam service-accounts describe "$GITHUB_ACTIONS_SA_EMAIL" >/dev/null 2>&1; then
    print_status "Deleting GitHub Actions service account..."
    gcloud iam service-accounts delete "$GITHUB_ACTIONS_SA_EMAIL" --quiet
    print_success "GitHub Actions service account deleted"
else
    print_warning "GitHub Actions service account not found"
fi

# === PHASE 3: TERRAFORM STATE BUCKET ===
print_status "🗑️ Deleting Terraform state bucket..."

if gsutil ls "gs://$TERRAFORM_STATE_BUCKET" >/dev/null 2>&1; then
    print_status "Deleting all objects in bucket..."
    gsutil rm -r "gs://$TERRAFORM_STATE_BUCKET" || true
    print_success "Terraform state bucket deleted"
else
    print_warning "Terraform state bucket not found"
fi

# === PHASE 4: LOCAL CLEANUP ===
print_status "🧹 Cleaning local files and configurations..."

# Remove service account keys directory
rm -rf .gcp-keys 2>/dev/null || true

# Remove Terraform directory structure (keep modules for reuse)
rm -rf terraform/environments 2>/dev/null || true
rm -rf terraform/shared 2>/dev/null || true
rm -rf terraform/.gitignore 2>/dev/null || true

# Remove GitHub Actions workflows
rm -rf .github 2>/dev/null || true

# Remove apps structure if empty/basic
if [ -d "apps" ]; then
    # Only remove if it's the basic structure from phase 1
    if [ ! -f "apps/service-a/package.json" ]; then
        rm -rf apps 2>/dev/null || true
    fi
fi

# Remove any terraform state files
find . -name "*.tfstate*" -delete 2>/dev/null || true
find . -name ".terraform*" -type d -exec rm -rf {} + 2>/dev/null || true

print_success "Local cleanup completed"

echo ""
print_success "🎉 Phase 1 foundation destroyed successfully!"

echo ""
print_status "📋 What was destroyed:"
echo "  ✅ Service accounts (terraform, github-actions)"
echo "  ✅ IAM policy bindings"
echo "  ✅ GCS bucket for Terraform state"
echo "  ✅ Local Terraform configurations"
echo "  ✅ GitHub Actions workflow templates"

echo ""
print_status "📝 Next Steps:"
echo "  1. To rebuild everything: ./scripts/1.\\ setup-phase-1.sh"
echo "  2. To rebuild just Phase 2: ./scripts/3.\\ setup-phase-2.sh (after Phase 1)"

echo ""
print_warning "⚠️ Note: Local development tools (brew packages) were NOT removed"
echo "   You can manually remove them if needed: brew uninstall terraform kubectl helm k9s"

echo ""
print_success "Phase 1 destroy script completed! 🚀"
