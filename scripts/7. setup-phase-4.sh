#!/bin/bash

set -e

# Phase 4: Basic Deployment & Connectivity
# This script deploys the NestJS applications to GKE with basic load balancing and connectivity testing

echo "🚀 Starting Phase 4: Basic Deployment & Connectivity"
echo "===================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

title() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Get GCP project ID
get_project_id() {
    if [ -n "$GOOGLE_CLOUD_PROJECT" ]; then
        echo "$GOOGLE_CLOUD_PROJECT"
    else
        gcloud config get-value project 2>/dev/null || echo ""
    fi
}

# Check prerequisites
title "Checking Prerequisites"

# Check if we're in the right directory
if [ ! -f "gke-deployment-plan.md" ]; then
    error "Please run this script from the project root directory."
    exit 1
fi

# Check if gcloud is installed and authenticated
if ! command -v gcloud &> /dev/null; then
    error "gcloud CLI is not installed. Please install and configure gcloud."
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed. Please install kubectl."
    exit 1
fi

# Get project ID
PROJECT_ID=$(get_project_id)
if [ -z "$PROJECT_ID" ]; then
    error "No GCP project configured. Please run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

log "Using GCP Project: $PROJECT_ID"

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 > /dev/null; then
    error "gcloud is not authenticated. Please run: gcloud auth login"
    exit 1
fi

# Check if kubectl is configured for GKE cluster
if ! kubectl cluster-info &> /dev/null; then
    error "kubectl is not configured for GKE cluster. Please run: gcloud container clusters get-credentials CLUSTER_NAME --zone=ZONE"
    exit 1
fi

CLUSTER_NAME=$(kubectl config current-context | sed 's/.*_//')
log "Connected to GKE cluster: $CLUSTER_NAME"

# Check if Docker images exist in Artifact Registry
REGION="asia-southeast1"
REGISTRY_URL="$REGION-docker.pkg.dev/$PROJECT_ID/infra-gke"

log "Checking Artifact Registry for container images..."
if ! gcloud artifacts repositories describe infra-gke --location=$REGION &> /dev/null; then
    error "Artifact Registry repository 'infra-gke' not found. Please run Phase 2 setup first."
    exit 1
fi

log "✅ All prerequisites met"

# Build and push Docker images
title "Building and Pushing Container Images"

# Configure Docker authentication for Artifact Registry
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

# Create buildx builder for multi-platform builds if it doesn't exist
if ! docker buildx ls | grep -q multiplatform-builder; then
    log "Creating buildx builder for multi-platform builds..."
    docker buildx create --use --name multiplatform-builder
else
    log "Using existing buildx builder..."
    docker buildx use multiplatform-builder
fi

log "Building Service A image for AMD64 platform..."
cd apps/service-a
docker buildx build --platform linux/amd64 -t $REGISTRY_URL/service-a:latest --push .
docker buildx build --platform linux/amd64 -t $REGISTRY_URL/service-a:$(date +%Y%m%d-%H%M%S) --push .

cd ../service-b
log "Building Service B image for AMD64 platform..."
docker buildx build --platform linux/amd64 -t $REGISTRY_URL/service-b:latest --push .
docker buildx build --platform linux/amd64 -t $REGISTRY_URL/service-b:$(date +%Y%m%d-%H%M%S) --push .

cd ../..

log "✅ Container images built and pushed with correct platform (linux/amd64)"

# Update K8s manifests with actual project ID
title "Updating Kubernetes Manifests"

log "Updating Service A deployment with project ID..."
sed "s/PROJECT_ID/$PROJECT_ID/g" apps/service-a/k8s/deployment.yaml > /tmp/service-a-deployment.yaml

log "Updating Service B deployment with project ID..."
sed "s/PROJECT_ID/$PROJECT_ID/g" apps/service-b/k8s/deployment.yaml > /tmp/service-b-deployment.yaml

log "✅ Kubernetes manifests updated"

# Create namespace if it doesn't exist
title "Setting up Kubernetes Namespace"

NAMESPACE="infra-gke"
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    log "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE
else
    log "Namespace $NAMESPACE already exists"
fi

kubectl config set-context --current --namespace=$NAMESPACE
log "✅ Using namespace: $NAMESPACE"

# Deploy applications
title "Deploying Applications to GKE"

log "Deploying Service A..."
kubectl apply -f /tmp/service-a-deployment.yaml -n $NAMESPACE

log "Deploying Service B..."
kubectl apply -f /tmp/service-b-deployment.yaml -n $NAMESPACE

log "✅ Applications deployed"

# Wait for deployments to be ready
title "Waiting for Deployments to be Ready"

log "Waiting for Service A deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/service-a -n $NAMESPACE

log "Waiting for Service B deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/service-b -n $NAMESPACE

log "✅ All deployments are ready"

# Create LoadBalancer services for external access
title "Creating External LoadBalancer Services"

log "Creating LoadBalancer service for Service A..."
cat <<EOF | kubectl apply -f - -n $NAMESPACE
apiVersion: v1
kind: Service
metadata:
  name: service-a-loadbalancer
  labels:
    app: service-a
    type: loadbalancer
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
    name: http
  selector:
    app: service-a
EOF

log "Creating LoadBalancer service for Service B..."
cat <<EOF | kubectl apply -f - -n $NAMESPACE
apiVersion: v1
kind: Service
metadata:
  name: service-b-loadbalancer
  labels:
    app: service-b
    type: loadbalancer
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 3001
    protocol: TCP
    name: http
  selector:
    app: service-b
EOF

log "✅ LoadBalancer services created"

# Create basic Ingress
title "Creating Basic Ingress Configuration"

log "Creating basic ingress for path-based routing..."
cat <<EOF | kubectl apply -f - -n $NAMESPACE
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: infra-gke-ingress
  annotations:
    kubernetes.io/ingress.class: "gce"
    kubernetes.io/ingress.global-static-ip-name: "infra-gke-ip"
    networking.gke.io/managed-certificates: "infra-gke-ssl-cert"
spec:
  rules:
  - http:
      paths:
      - path: /users/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: service-a
            port:
              number: 80
      - path: /products/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: service-b
            port:
              number: 80
      - path: /api/v1/users/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: service-a
            port:
              number: 80
      - path: /api/v1/products/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: service-b
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: service-a
            port:
              number: 80
EOF

log "✅ Basic ingress configuration created"

# Wait for LoadBalancer external IPs
title "Waiting for External IP Addresses"

log "Waiting for Service A LoadBalancer external IP..."
while true; do
    EXTERNAL_IP_A=$(kubectl get service service-a-loadbalancer -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP_A" ] && [ "$EXTERNAL_IP_A" != "null" ]; then
        log "Service A external IP: $EXTERNAL_IP_A"
        break
    fi
    log "Waiting for external IP assignment..."
    sleep 10
done

log "Waiting for Service B LoadBalancer external IP..."
while true; do
    EXTERNAL_IP_B=$(kubectl get service service-b-loadbalancer -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP_B" ] && [ "$EXTERNAL_IP_B" != "null" ]; then
        log "Service B external IP: $EXTERNAL_IP_B"
        break
    fi
    log "Waiting for external IP assignment..."
    sleep 10
done

log "✅ External IP addresses assigned"

# Basic connectivity testing
title "Basic Connectivity Testing"

log "Testing Service A health endpoint..."
if curl -s --max-time 30 "http://$EXTERNAL_IP_A/api/v1/health" > /dev/null; then
    log "✅ Service A health check successful"
else
    warn "⚠️ Service A health check failed - service may still be starting up"
fi

log "Testing Service B health endpoint..."
if curl -s --max-time 30 "http://$EXTERNAL_IP_B/api/v1/health" > /dev/null; then
    log "✅ Service B health check successful"
else
    warn "⚠️ Service B health check failed - service may still be starting up"
fi

# Test internal service-to-service connectivity
title "Testing Internal Service Discovery"

log "Testing internal DNS resolution..."
kubectl run test-pod --image=alpine/curl:8.10.1 --rm -it --restart=Never -n $NAMESPACE -- /bin/sh -c "
    echo 'Testing Service A internal DNS...'
    curl -s --max-time 10 http://service-a.${NAMESPACE}.svc.cluster.local/api/v1/health || echo 'Service A internal connectivity failed'
    echo 'Testing Service B internal DNS...'
    curl -s --max-time 10 http://service-b.${NAMESPACE}.svc.cluster.local/api/v1/health || echo 'Service B internal connectivity failed'
" 2>/dev/null || warn "Internal connectivity test pods had issues"

log "✅ Internal service discovery testing completed"

# Display deployment information
title "Deployment Information"

echo ""
echo "📋 Deployment Summary:"
echo "  • Namespace: $NAMESPACE"
echo "  • GKE Cluster: $CLUSTER_NAME"
echo "  • Project ID: $PROJECT_ID"
echo ""

echo "🌐 External Access URLs:"
echo "  • Service A (User Management):"
echo "    - LoadBalancer IP: http://$EXTERNAL_IP_A"
echo "    - Health Check: http://$EXTERNAL_IP_A/api/v1/health"
echo "    - API Docs: http://$EXTERNAL_IP_A/api/docs"
echo "    - Users API: http://$EXTERNAL_IP_A/api/v1/users"
echo ""
echo "  • Service B (Product Catalog):"
echo "    - LoadBalancer IP: http://$EXTERNAL_IP_B"
echo "    - Health Check: http://$EXTERNAL_IP_B/api/v1/health"
echo "    - API Docs: http://$EXTERNAL_IP_B/api/docs"
echo "    - Products API: http://$EXTERNAL_IP_B/api/v1/products"
echo ""

echo "🔄 Internal Service Discovery:"
echo "  • Service A: http://service-a.${NAMESPACE}.svc.cluster.local"
echo "  • Service B: http://service-b.${NAMESPACE}.svc.cluster.local"
echo ""

echo "📊 Kubernetes Resources:"
echo "  • Deployments: service-a, service-b"
echo "  • ClusterIP Services: service-a, service-b"
echo "  • LoadBalancer Services: service-a-loadbalancer, service-b-loadbalancer"
echo "  • Ingress: infra-gke-ingress"
echo ""

# Display next steps
title "Next Steps"

echo "To monitor the deployment:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl get services -n $NAMESPACE"
echo "  kubectl get ingress -n $NAMESPACE"
echo ""
echo "To view logs:"
echo "  kubectl logs -f deployment/service-a -n $NAMESPACE"
echo "  kubectl logs -f deployment/service-b -n $NAMESPACE"
echo ""
echo "To run validation:"
echo "  ./scripts/8.\\ validate-phase-4.sh"
echo ""
echo "To proceed to Phase 5 (Basic Observability):"
echo "  Ensure all services are healthy and accessible"
echo "  Then run the Phase 5 setup script when available"
echo ""

# Cleanup temporary files
rm -f /tmp/service-a-deployment.yaml /tmp/service-b-deployment.yaml

log "🎉 Phase 4 setup completed successfully!"
log "Your applications are now deployed to GKE with basic load balancing."
log "Run the validation script to verify everything is working correctly."
