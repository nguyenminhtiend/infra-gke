#!/bin/bash

# Phase 2 Validation Script
# Validates that Phase 2 basic infrastructure was created successfully

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_ID="infra-gke-469413"
REGION="asia-southeast1"
ENVIRONMENT="dev"
TERRAFORM_DIR="terraform/environments/dev"

print_status() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "🔍 Phase 2 Validation - Basic Infrastructure"
echo "============================================="

# Check if we can get terraform outputs
print_status "Checking Terraform deployment..."
cd "$TERRAFORM_DIR"

if terraform output >/dev/null 2>&1; then
    print_success "Terraform state is accessible"

    # Get outputs
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    NETWORK_NAME=$(terraform output -raw network_name 2>/dev/null || echo "")
    REGISTRY_URL=$(terraform output -raw artifact_registry_url 2>/dev/null || echo "")

    if [ -n "$CLUSTER_NAME" ] && [ -n "$NETWORK_NAME" ] && [ -n "$REGISTRY_URL" ]; then
        print_success "All Terraform outputs are available"
    else
        print_error "Some Terraform outputs are missing"
    fi
else
    print_error "Cannot access Terraform state"
fi

cd - >/dev/null

# Check VPC Network
print_status "Validating VPC network..."
if gcloud compute networks describe "${ENVIRONMENT}-vpc" --project="$PROJECT_ID" >/dev/null 2>&1; then
    print_success "VPC network exists: ${ENVIRONMENT}-vpc"
else
    print_error "VPC network not found: ${ENVIRONMENT}-vpc"
fi

# Check Subnet
print_status "Validating subnet..."
if gcloud compute networks subnets describe "${ENVIRONMENT}-subnet" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    print_success "Subnet exists: ${ENVIRONMENT}-subnet"

    # Check secondary ranges
    SECONDARY_RANGES=$(gcloud compute networks subnets describe "${ENVIRONMENT}-subnet" \
        --region="$REGION" --project="$PROJECT_ID" \
        --format="value(secondaryIpRanges[].rangeName)" 2>/dev/null)

    if echo "$SECONDARY_RANGES" | grep -q "gke-pods" && echo "$SECONDARY_RANGES" | grep -q "gke-services"; then
        print_success "Secondary IP ranges configured for GKE"
    else
        print_error "GKE secondary IP ranges not found"
    fi
else
    print_error "Subnet not found: ${ENVIRONMENT}-subnet"
fi

# Check Firewall Rules
print_status "Validating firewall rules..."
FIREWALL_RULES=(
    "${ENVIRONMENT}-vpc-allow-internal"
    "${ENVIRONMENT}-vpc-allow-ssh"
    "${ENVIRONMENT}-vpc-allow-http-https"
)

for rule in "${FIREWALL_RULES[@]}"; do
    if gcloud compute firewall-rules describe "$rule" --project="$PROJECT_ID" >/dev/null 2>&1; then
        print_success "Firewall rule exists: $rule"
    else
        print_error "Firewall rule not found: $rule"
    fi
done

# Check Cloud Router and NAT
print_status "Validating Cloud Router and NAT..."
if gcloud compute routers describe "${ENVIRONMENT}-vpc-router" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    print_success "Cloud Router exists: ${ENVIRONMENT}-vpc-router"
else
    print_error "Cloud Router not found: ${ENVIRONMENT}-vpc-router"
fi

if gcloud compute routers nats describe "${ENVIRONMENT}-vpc-nat" --router="${ENVIRONMENT}-vpc-router" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    print_success "Cloud NAT exists: ${ENVIRONMENT}-vpc-nat"
else
    print_error "Cloud NAT not found: ${ENVIRONMENT}-vpc-nat"
fi

# Check GKE Cluster
print_status "Validating GKE cluster..."
if [ -n "$CLUSTER_NAME" ]; then
    if gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
        print_success "GKE cluster exists: $CLUSTER_NAME"

        # Check if it's Autopilot
        AUTOPILOT=$(gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(autopilot.enabled)" 2>/dev/null)
        if [ "$AUTOPILOT" = "True" ]; then
            print_success "Cluster is running in Autopilot mode"
        else
            print_error "Cluster is not in Autopilot mode"
        fi

        # Check cluster version
        CLUSTER_VERSION=$(gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(currentMasterVersion)" 2>/dev/null)
        print_success "Cluster version: $CLUSTER_VERSION"

        # Check if Workload Identity is enabled
        WI_POOL=$(gcloud container clusters describe "$CLUSTER_NAME" --region="$REGION" --project="$PROJECT_ID" --format="value(workloadIdentityConfig.workloadPool)" 2>/dev/null)
        if [ -n "$WI_POOL" ]; then
            print_success "Workload Identity is enabled: $WI_POOL"
        else
            print_error "Workload Identity is not enabled"
        fi

    else
        print_error "GKE cluster not found: $CLUSTER_NAME"
    fi
else
    print_error "Cluster name not available from Terraform output"
fi

# Check Artifact Registry
print_status "Validating Artifact Registry..."
REPO_NAME="${ENVIRONMENT}-container-images"
if gcloud artifacts repositories describe "$REPO_NAME" --location="$REGION" --project="$PROJECT_ID" >/dev/null 2>&1; then
    print_success "Artifact Registry repository exists: $REPO_NAME"

    # Check repository format
    REPO_FORMAT=$(gcloud artifacts repositories describe "$REPO_NAME" --location="$REGION" --project="$PROJECT_ID" --format="value(format)" 2>/dev/null)
    if [ "$REPO_FORMAT" = "DOCKER" ]; then
        print_success "Repository format is Docker"
    else
        print_error "Repository format is not Docker: $REPO_FORMAT"
    fi
else
    print_error "Artifact Registry repository not found: $REPO_NAME"
fi

# Check kubectl authentication prerequisites
print_status "Validating kubectl authentication prerequisites..."
if gcloud components list --filter="id:gke-gcloud-auth-plugin" --format="value(state.name)" | grep -q "Installed"; then
    print_success "gke-gcloud-auth-plugin is installed"
else
    print_error "gke-gcloud-auth-plugin is not installed. Run: gcloud components install gke-gcloud-auth-plugin"
fi

# Check kubectl connectivity
print_status "Validating kubectl connectivity..."
if command_exists kubectl; then
    # Check if cluster context is set
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if echo "$CURRENT_CONTEXT" | grep -q "$CLUSTER_NAME"; then
        print_success "kubectl context is set to the cluster"

        # Test cluster connectivity
        if kubectl cluster-info >/dev/null 2>&1; then
            print_success "Cluster is accessible via kubectl"

            # Check namespaces
            NAMESPACES=$(kubectl get namespaces -o name 2>/dev/null | wc -l)
            print_success "Can list namespaces ($NAMESPACES found)"

            # Check system pods
            SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
            if [ "$SYSTEM_PODS" -gt 0 ]; then
                print_success "System pods are running ($SYSTEM_PODS pods in kube-system)"
            else
                print_warning "No system pods found - cluster may still be initializing"
            fi

        else
            print_error "Cannot connect to cluster via kubectl"
        fi
    else
        print_error "kubectl context is not set to the cluster"
    fi
else
    print_error "kubectl is not installed"
fi

# Check Docker configuration for Artifact Registry
print_status "Validating Docker configuration..."
if command_exists docker; then
    # Check if Docker is running
    if docker info >/dev/null 2>&1; then
        print_success "Docker is running"

        # Check if gcloud auth is configured for Artifact Registry
        if gcloud auth list --filter="status:ACTIVE" --format="value(account)" | head -n1 >/dev/null 2>&1; then
            print_success "gcloud authentication is active"

            # Check Docker credential helper
            if gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet 2>/dev/null; then
                print_success "Docker is configured for Artifact Registry"
            else
                print_warning "Docker configuration for Artifact Registry may have issues"
            fi
        else
            print_error "No active gcloud authentication found"
        fi
    else
        print_warning "Docker is not running or not accessible"
    fi
else
    print_error "Docker is not installed"
fi

# Check IAM permissions
print_status "Validating service account permissions..."

# Check GitHub Actions service account permissions
SA_EMAIL="github-actions@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    print_success "GitHub Actions service account exists"

    # Check Artifact Registry permissions
    if gcloud artifacts repositories get-iam-policy "$REPO_NAME" --location="$REGION" --project="$PROJECT_ID" --format="value(bindings[].members[])" 2>/dev/null | grep -q "$SA_EMAIL"; then
        print_success "GitHub Actions SA has Artifact Registry permissions"
    else
        print_warning "GitHub Actions SA may not have Artifact Registry permissions"
    fi
else
    print_error "GitHub Actions service account not found"
fi

# Summary
echo ""
echo "🎯 Phase 2 Validation Summary"
echo "============================="
echo ""

# Count successful/failed checks
TOTAL_CHECKS=$(grep -c "print_success\|print_error" "$0" || echo "unknown")
echo "Infrastructure components validated."
echo ""

print_status "📊 Infrastructure Status:"
cd "$TERRAFORM_DIR"
if terraform output >/dev/null 2>&1; then
    echo "  Cluster: $(terraform output -raw cluster_name 2>/dev/null || echo 'N/A')"
    echo "  Network: $(terraform output -raw network_name 2>/dev/null || echo 'N/A')"
    echo "  Registry: $(terraform output -raw artifact_registry_url 2>/dev/null || echo 'N/A')"
fi
cd - >/dev/null

echo ""
print_status "📝 Next Steps:"
echo "  1. If all checks show ✓, Phase 2 is complete"
echo "  2. Any ✗ items should be investigated and fixed"
echo "  3. Ready to proceed to Phase 3: Application Setup"

echo ""
print_status "🔧 Useful Commands:"
echo "  • kubectl get namespaces                    # List all namespaces"
echo "  • kubectl get nodes                         # List cluster nodes (auto-provisioned)"
echo "  • gcloud container clusters list            # List all clusters"
echo "  • gcloud artifacts repositories list        # List artifact repositories"
echo "  • terraform -chdir=$TERRAFORM_DIR plan     # Check infrastructure drift"

echo ""
echo "Phase 2 validation completed! 🔍"
