#!/bin/bash

# Destroy Phase 2: Basic Infrastructure
# Destroys VPC network, GKE Autopilot cluster, and Artifact Registry

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

print_status "🗑️ Starting Phase 2 Destroy: Basic Infrastructure"
print_status "Project ID: $PROJECT_ID"
print_status "Region: $REGION"
print_status "Environment: $ENVIRONMENT"

echo ""
print_warning "⚠️ This will destroy:"
echo "  • GKE Autopilot cluster and all workloads"
echo "  • VPC network, subnets, and firewall rules"
echo "  • Artifact Registry repositories and images"
echo "  • Cloud NAT and external IP addresses"
echo "  • All Kubernetes resources in the cluster"

echo ""
read -p "Are you sure you want to destroy Phase 2 infrastructure? (type 'yes' to confirm): " confirm

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

# === PHASE 1: KUBERNETES CLEANUP ===
print_status "🧹 Cleaning up Kubernetes resources..."

if command_exists kubectl; then
    # Try to connect to any existing cluster
    CLUSTER_NAME=$(gcloud container clusters list --region=$REGION --format="value(name)" 2>/dev/null | head -n1 || echo "")

    if [ -n "$CLUSTER_NAME" ]; then
        print_status "Connecting to cluster: $CLUSTER_NAME"
        if gcloud container clusters get-credentials "$CLUSTER_NAME" --region=$REGION 2>/dev/null; then
            # Delete all namespaces except system ones
            kubectl get namespaces --no-headers -o custom-columns=":metadata.name" | grep -v "^kube-\|^default$\|^gmp-" | xargs -r kubectl delete namespace --timeout=300s 2>/dev/null || true

            # Clean up any remaining LoadBalancer services and ingresses
            kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer -o name 2>/dev/null | xargs -r kubectl delete --timeout=60s 2>/dev/null || true
            kubectl get ingress --all-namespaces -o name 2>/dev/null | xargs -r kubectl delete --timeout=60s 2>/dev/null || true
        fi
    fi
    print_success "Kubernetes cleanup completed"
else
    print_warning "kubectl not available - skipping Kubernetes cleanup"
fi

# === PHASE 2: TERRAFORM DESTROY ===
print_status "🗑️ Using Terraform to destroy infrastructure..."

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

# Check authentication without prompting for login
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    print_error "Application default credentials not configured"
    print_error "Run: gcloud auth application-default login"
    exit 1
fi

# Initialize Terraform
print_status "🔧 Initializing Terraform..."
terraform init

# Validate Terraform configuration
print_status "🔍 Validating Terraform configuration..."
terraform validate

# Plan destroy
print_status "📋 Planning destroy operation..."
if ! terraform plan -destroy -out=destroy.tfplan; then
    print_error "Terraform plan failed"
    exit 1
fi

# Show what will be destroyed
echo ""
print_status "📊 Destroy Summary:"
echo "The following resources will be destroyed:"
echo ""

# Extract resource counts from plan
terraform show -json destroy.tfplan | jq -r '
.resource_changes[] |
select(.change.actions[] == "delete") |
.type' | sort | uniq -c | while read count type; do
    echo "  • $count x $type"
done

echo ""
read -p "Proceed with destroying these resources? (y/N): " final_confirm

if [[ $final_confirm =~ ^[Yy]$ ]]; then
    print_status "🚀 Destroying infrastructure..."

    # Apply the destroy plan
    terraform apply destroy.tfplan

    print_success "Terraform destroy completed!"

    # Clean up plan file
    rm -f destroy.tfplan
else
    print_warning "Destroy cancelled"
    rm -f destroy.tfplan
    exit 0
fi

# === PHASE 3: MANUAL CLEANUP FALLBACK ===
print_status "🧹 Manual cleanup of any remaining resources..."

# Clean up any orphaned resources that Terraform might have missed
gcloud compute addresses list --filter="region:($REGION)" --format="value(name)" 2>/dev/null | while read ip_name; do
    if [ -n "$ip_name" ]; then
        gcloud compute addresses delete "$ip_name" --region="$REGION" --quiet 2>/dev/null || true
    fi
done

# Clean up any orphaned disks
gcloud compute disks list --filter="zone:($REGION)" --format="value(name,zone)" 2>/dev/null | while read disk_info; do
    if [ -n "$disk_info" ]; then
        disk_name=$(echo "$disk_info" | awk '{print $1}')
        disk_zone=$(echo "$disk_info" | awk '{print $2}')
        gcloud compute disks delete "$disk_name" --zone="$disk_zone" --quiet 2>/dev/null || true
    fi
done

print_success "Manual cleanup completed"

# Return to project root
cd - >/dev/null

# === PHASE 4: LOCAL CLEANUP ===
print_status "🧹 Cleaning local artifacts..."

# Remove local Terraform state and plans
rm -rf terraform/environments/dev/.terraform* 2>/dev/null || true
rm -rf terraform/environments/dev/terraform.tfstate* 2>/dev/null || true
rm -rf terraform/environments/dev/*tfplan 2>/dev/null || true

# Clean Docker images related to this project
if command_exists docker; then
    docker images --format "{{.Repository}}:{{.Tag}}" | grep "$REGION-docker.pkg.dev/$PROJECT_ID" | xargs -r docker rmi 2>/dev/null || true
fi

print_success "Local cleanup completed"

echo ""
print_success "🎉 Phase 2 infrastructure destroyed successfully!"

echo ""
print_status "📋 What was destroyed:"
echo "  ✅ GKE Autopilot cluster and all workloads"
echo "  ✅ VPC network, subnets, and firewall rules"
echo "  ✅ Artifact Registry repositories and images"
echo "  ✅ Cloud NAT and external IP addresses"
echo "  ✅ Local Terraform state and artifacts"

echo ""
print_status "📝 Next Steps:"
echo "  1. Run Phase 1 destroy if needed: ./scripts/destroy-phase-1.sh"
echo "  2. Or rebuild Phase 2: ./scripts/3.\\ setup-phase-2.sh"

echo ""
print_success "Phase 2 destroy script completed! 🚀"
