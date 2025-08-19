#!/bin/bash

# Unified GKE Infrastructure Cleanup Script
# Combines Terraform cleanup + manual fallback + local cleanup + restart guidance
# This is the ONLY cleanup script you need!

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Auto-detected
REGION="asia-southeast1"
ENVIRONMENT="dev"
TERRAFORM_DIR="terraform/environments/dev"
NAMESPACE="infra-gke"

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_title() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

confirm_action() {
    local message="$1"
    echo ""
    print_warning "⚠️  DESTRUCTIVE ACTION: $message"
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    [[ "$confirm" == "yes" ]]
}

get_current_project() { gcloud config get-value project 2>/dev/null || echo ""; }

print_title "🗑️  Unified GKE Cleanup Script"

# Auto-detect project
PROJECT_ID=$(get_current_project)
if [ -z "$PROJECT_ID" ]; then
    print_error "No GCP project configured. Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

TERRAFORM_STATE_BUCKET="${PROJECT_ID}-terraform-state"
print_status "Project ID: $PROJECT_ID"
print_status "Region: $REGION"

echo ""
print_warning "This script will completely destroy:"
echo "  🔥 All Kubernetes resources (deployments, services, ingress)"
echo "  🔥 GKE clusters and node pools"
echo "  🔥 VPC networks, subnets, firewall rules"
echo "  🔥 Artifact Registry repositories and images"
echo "  🔥 External IP addresses and NAT gateways"
echo "  🔥 Service accounts and IAM bindings (optional)"
echo "  🔥 Terraform state bucket (optional)"
echo "  🔥 Local Docker images and build artifacts"

if ! confirm_action "This will completely destroy your GKE infrastructure"; then
    exit 0
fi

# === PHASE 1: KUBERNETES CLEANUP ===
print_title "🧹 Phase 1: Kubernetes Resources"

if command_exists kubectl; then
    # Try to connect to any existing cluster
    CLUSTER_NAME=$(gcloud container clusters list --region=$REGION --format="value(name)" 2>/dev/null | head -n1 || echo "")

    if [ -n "$CLUSTER_NAME" ]; then
        print_status "Connecting to cluster: $CLUSTER_NAME"
        if gcloud container clusters get-credentials "$CLUSTER_NAME" --region=$REGION 2>/dev/null; then
            # Delete namespace and all LoadBalancer services
            if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
                print_status "Deleting namespace: $NAMESPACE"
                kubectl delete namespace $NAMESPACE --timeout=300s || print_warning "Namespace deletion had issues"
            fi

            # Clean up any remaining LoadBalancer services
            kubectl get services --all-namespaces --field-selector spec.type=LoadBalancer -o name 2>/dev/null | xargs -r kubectl delete --timeout=60s 2>/dev/null || true
            kubectl get ingress --all-namespaces -o name 2>/dev/null | xargs -r kubectl delete --timeout=60s 2>/dev/null || true
        fi
    fi
    print_success "Kubernetes cleanup completed"
else
    print_warning "kubectl not available - skipping Kubernetes cleanup"
fi

# === PHASE 2: TERRAFORM CLEANUP (with fallback) ===
print_title "🧹 Phase 2: Infrastructure (Terraform + Manual Fallback)"

terraform_success=false

# Try Terraform first if available
if command_exists terraform && [ -d "$TERRAFORM_DIR" ]; then
    print_status "Attempting Terraform cleanup..."
    cd "$TERRAFORM_DIR"

    # Check authentication
    if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
        print_warning "Application default credentials not configured"
        gcloud auth application-default login 2>/dev/null || true
    fi

    if terraform init 2>/dev/null && terraform plan -destroy -out=destroy.tfplan 2>/dev/null; then
        if confirm_action "Use Terraform to destroy infrastructure"; then
            if terraform apply destroy.tfplan; then
                terraform_success=true
                print_success "Terraform cleanup successful"
            fi
        fi
        rm -f destroy.tfplan
    fi
    cd - >/dev/null
fi

# Manual cleanup fallback
if [ "$terraform_success" = false ]; then
    print_status "Using manual cleanup (gcloud commands)..."

    # 1. Delete GKE clusters
    print_status "Deleting GKE clusters..."
    gcloud container clusters list --format="value(name,zone)" 2>/dev/null | while read cluster_info; do
        if [ -n "$cluster_info" ]; then
            cluster_name=$(echo "$cluster_info" | awk '{print $1}')
            cluster_zone=$(echo "$cluster_info" | awk '{print $2}')
            print_status "Deleting cluster: $cluster_name"
            gcloud container clusters delete "$cluster_name" --zone="$cluster_zone" --quiet --async || true
        fi
    done

    # 2. Delete Artifact Registry
    print_status "Deleting Artifact Registry repositories..."
    gcloud artifacts repositories list --location="$REGION" --format="value(name)" 2>/dev/null | while read repo; do
        if [ -n "$repo" ]; then
            repo_name=$(basename "$repo")
            gcloud artifacts repositories delete "$repo_name" --location="$REGION" --quiet || true
        fi
    done

    # 3. Delete Cloud NAT (to release auto IPs)
    print_status "Deleting Cloud NAT and routers..."
    gcloud compute routers list --filter="region:($REGION)" --format="value(name)" 2>/dev/null | while read router; do
        if [ -n "$router" ]; then
            # Delete NAT configs first
            gcloud compute routers nats list --router="$router" --region="$REGION" --format="value(name)" 2>/dev/null | while read nat; do
                [ -n "$nat" ] && gcloud compute routers nats delete "$nat" --router="$router" --region="$REGION" --quiet 2>/dev/null || true
            done
            # Delete router
            gcloud compute routers delete "$router" --region="$REGION" --quiet || true
        fi
    done

    # 4. Delete external IPs
    print_status "Deleting external IP addresses..."
    gcloud compute addresses list --filter="region:($REGION)" --format="value(name,addressType)" 2>/dev/null | while read ip_info; do
        if [ -n "$ip_info" ]; then
            ip_name=$(echo "$ip_info" | awk '{print $1}')
            ip_type=$(echo "$ip_info" | awk '{print $2}')
            [ "$ip_type" = "EXTERNAL" ] && gcloud compute addresses delete "$ip_name" --region="$REGION" --quiet || true
        fi
    done

    # 5. Delete orphaned disks
    print_status "Deleting orphaned disks..."
    gcloud compute disks list --filter="zone:($REGION)" --format="value(name,zone)" 2>/dev/null | while read disk_info; do
        if [ -n "$disk_info" ]; then
            disk_name=$(echo "$disk_info" | awk '{print $1}')
            disk_zone=$(echo "$disk_info" | awk '{print $2}')
            gcloud compute disks delete "$disk_name" --zone="$disk_zone" --quiet || true
        fi
    done

    # 6. Wait for clusters and delete networks
    print_status "Waiting for cluster deletion to complete..."
    sleep 60  # Give clusters time to delete

    gcloud compute networks list --filter="name~.*vpc.* OR name~.*gke.*" --format="value(name)" 2>/dev/null | while read network; do
        if [ -n "$network" ] && [ "$network" != "default" ]; then
            # Delete firewall rules
            gcloud compute firewall-rules list --filter="network:$network" --format="value(name)" 2>/dev/null | while read rule; do
                [ -n "$rule" ] && gcloud compute firewall-rules delete "$rule" --quiet 2>/dev/null || true
            done

            # Delete subnets
            gcloud compute networks subnets list --filter="network:$network" --format="value(name,region)" 2>/dev/null | while read subnet_info; do
                if [ -n "$subnet_info" ]; then
                    subnet_name=$(echo "$subnet_info" | awk '{print $1}')
                    subnet_region=$(echo "$subnet_info" | awk '{print $2}')
                    gcloud compute networks subnets delete "$subnet_name" --region="$subnet_region" --quiet 2>/dev/null || true
                fi
            done

            # Delete network
            gcloud compute networks delete "$network" --quiet 2>/dev/null || print_warning "Network $network may have dependencies"
        fi
    done

    print_success "Manual infrastructure cleanup completed"
fi

# === PHASE 3: SERVICE ACCOUNTS & STATE (Optional) ===
print_title "🧹 Phase 3: Service Accounts & State (Optional)"

if confirm_action "Delete service accounts and Terraform state bucket"; then
    # Remove service accounts
    SA_NAMES=("terraform" "github-actions")
    for sa in "${SA_NAMES[@]}"; do
        SA_EMAIL="${sa}@${PROJECT_ID}.iam.gserviceaccount.com"
        if gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1; then
            print_status "Deleting service account: $sa"
            gcloud iam service-accounts delete "$SA_EMAIL" --quiet || true
        fi
    done

    # Delete state bucket
    if gsutil ls "gs://$TERRAFORM_STATE_BUCKET" >/dev/null 2>&1; then
        print_status "Deleting Terraform state bucket..."
        gsutil rm -r "gs://$TERRAFORM_STATE_BUCKET" || true
    fi

    print_success "Service accounts and state bucket deleted"
else
    print_warning "Service accounts and state bucket preserved"
fi

# === PHASE 4: LOCAL CLEANUP ===
print_title "🧹 Phase 4: Local Environment Cleanup"

# Docker cleanup
if command_exists docker; then
    print_status "Cleaning local Docker images..."
    docker rmi service-a:latest service-b:latest 2>/dev/null || true
    docker images --format "{{.Repository}}:{{.Tag}}" | grep "$REGION-docker.pkg.dev/$PROJECT_ID" | xargs -r docker rmi 2>/dev/null || true
    docker image prune -f >/dev/null 2>&1 || true
fi

# Local files cleanup
print_status "Cleaning build artifacts and caches..."
rm -rf apps/service-{a,b}/{dist,node_modules,logs} 2>/dev/null || true
rm -rf node_modules 2>/dev/null || true
rm -rf terraform/environments/dev/.terraform* terraform/environments/dev/terraform.tfstate* terraform/environments/dev/*tfplan 2>/dev/null || true
rm -rf .gcp-keys/*.json 2>/dev/null || true

print_success "Local cleanup completed"

# === PHASE 5: AUTHENTICATION CHECK ===
print_title "🔑 Phase 5: Authentication Status"

if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    print_success "Application default credentials are configured and valid"
else
    print_warning "Application default credentials may need to be reconfigured"
    print_status "Run: gcloud auth application-default login"
fi

# === COMPLETION & RESTART INSTRUCTIONS ===
print_title "🎉 Cleanup Complete - Ready for Fresh Start!"

echo ""
print_success "🗑️  Everything has been cleaned up!"
echo ""
print_status "📋 What was destroyed:"
echo "  ✅ Kubernetes resources (pods, services, ingress)"
echo "  ✅ GKE clusters and infrastructure"
echo "  ✅ VPC networks, subnets, firewall rules"
echo "  ✅ Artifact Registry repositories"
echo "  ✅ External IPs and NAT gateways"
echo "  ✅ Local Docker images and build artifacts"
echo "  ✅ Service accounts and state bucket (if selected)"

echo ""
print_title "🚀 To Start Fresh - Run These Commands:"
echo ""
echo "📋 Phase 1 - Foundation & Local Setup:"
echo "  ./scripts/1.\\ setup-phase-1.sh"
echo "  ./scripts/2.\\ validate-phase-1.sh"
echo ""
echo "📋 Phase 2 - Basic Infrastructure:"
echo "  ./scripts/3.\\ setup-phase-2.sh"
echo "  ./scripts/4.\\ validate-phase-2.sh"
echo ""
echo "📋 Phase 3 - Application Setup:"
echo "  ./scripts/5.\\ setup-phase-3.sh"
echo "  ./scripts/6.\\ validate-phase-3.sh"
echo ""
echo "📋 Phase 4 - Deployment & Connectivity:"
echo "  ./scripts/7.\\ setup-phase-4.sh"
echo "  ./scripts/8.\\ validate-phase-4.sh"

echo ""
print_status "🔧 Pre-flight checklist:"
echo "  • Ensure Docker Desktop is running"
echo "  • Verify GCP quotas and permissions"
echo "  • Check project ID in setup scripts if needed"

echo ""
print_success "🌟 Ready to rebuild your GKE infrastructure from scratch! 🌟"
