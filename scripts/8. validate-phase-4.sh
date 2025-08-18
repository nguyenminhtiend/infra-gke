#!/bin/bash

set -e

# Phase 4: Basic Deployment & Connectivity Validation
# This script validates the GKE deployment with load balancing and connectivity

echo "🔍 Starting Phase 4: Basic Deployment & Connectivity Validation"
echo "=============================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CHECKS_TOTAL=0
CHECKS_PASSED=0
CHECKS_FAILED=0

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

check() {
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
    if eval "$2"; then
        log "✅ $1"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        error "❌ $1"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
        return 1
    fi
}

# Get GCP project ID
get_project_id() {
    if [ -n "$GOOGLE_CLOUD_PROJECT" ]; then
        echo "$GOOGLE_CLOUD_PROJECT"
    else
        gcloud config get-value project 2>/dev/null || echo ""
    fi
}

# Check if we're in the right directory
if [ ! -f "gke-deployment-plan.md" ]; then
    error "Please run this script from the project root directory."
    exit 1
fi

# Get project and namespace info
PROJECT_ID=$(get_project_id)
NAMESPACE="infra-gke"
REGION="asia-southeast1"

# Validate Prerequisites
title "Validating Prerequisites"

check "gcloud CLI is installed" "command -v gcloud > /dev/null 2>&1"
check "gke-gcloud-auth-plugin is installed" "gcloud components list --filter='id:gke-gcloud-auth-plugin' --format='value(state.name)' | grep -q 'Installed'"
check "kubectl is installed" "command -v kubectl > /dev/null 2>&1"
check "curl is installed" "command -v curl > /dev/null 2>&1"

if [ -n "$PROJECT_ID" ]; then
    check "GCP project is configured" "[ -n '$PROJECT_ID' ]"
    log "Using GCP Project: $PROJECT_ID"
else
    error "No GCP project configured"
    exit 1
fi

check "kubectl is connected to cluster" "kubectl cluster-info > /dev/null 2>&1"
if kubectl cluster-info > /dev/null 2>&1; then
    CLUSTER_NAME=$(kubectl config current-context | sed 's/.*_//')
    log "Connected to GKE cluster: $CLUSTER_NAME"
fi

# Validate Namespace and Context
title "Validating Namespace and Context"

check "Namespace '$NAMESPACE' exists" "kubectl get namespace $NAMESPACE > /dev/null 2>&1"
check "Current context uses correct namespace" "kubectl config view --minify --output 'jsonpath={..namespace}' | grep -q $NAMESPACE"

# Validate Container Images in Artifact Registry
title "Validating Container Images"

REGISTRY_URL="$REGION-docker.pkg.dev/$PROJECT_ID/infra-gke"

check "Artifact Registry repository exists" "gcloud artifacts repositories describe infra-gke --location=$REGION > /dev/null 2>&1"
check "Service A image exists in registry" "gcloud artifacts docker images list $REGISTRY_URL --filter='IMAGE:service-a' --limit=1 --format='value(IMAGE)' | head -1 | grep -q service-a"
check "Service B image exists in registry" "gcloud artifacts docker images list $REGISTRY_URL --filter='IMAGE:service-b' --limit=1 --format='value(IMAGE)' | head -1 | grep -q service-b"

# Validate Deployments
title "Validating Kubernetes Deployments"

check "Service A deployment exists" "kubectl get deployment service-a -n $NAMESPACE > /dev/null 2>&1"
check "Service B deployment exists" "kubectl get deployment service-b -n $NAMESPACE > /dev/null 2>&1"

if kubectl get deployment service-a -n $NAMESPACE > /dev/null 2>&1; then
    REPLICAS_A=$(kubectl get deployment service-a -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED_A=$(kubectl get deployment service-a -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    check "Service A deployment is ready ($REPLICAS_A/$DESIRED_A replicas)" "[ '$REPLICAS_A' = '$DESIRED_A' ]"
fi

if kubectl get deployment service-b -n $NAMESPACE > /dev/null 2>&1; then
    REPLICAS_B=$(kubectl get deployment service-b -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
    DESIRED_B=$(kubectl get deployment service-b -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    check "Service B deployment is ready ($REPLICAS_B/$DESIRED_B replicas)" "[ '$REPLICAS_B' = '$DESIRED_B' ]"
fi

# Validate Pods
title "Validating Pod Status"

SERVICE_A_PODS=$(kubectl get pods -n $NAMESPACE -l app=service-a --field-selector=status.phase=Running --no-headers | wc -l)
SERVICE_B_PODS=$(kubectl get pods -n $NAMESPACE -l app=service-b --field-selector=status.phase=Running --no-headers | wc -l)

check "Service A pods are running" "[ $SERVICE_A_PODS -gt 0 ]"
check "Service B pods are running" "[ $SERVICE_B_PODS -gt 0 ]"

# Check pod readiness
if [ $SERVICE_A_PODS -gt 0 ]; then
    READY_A=$(kubectl get pods -n $NAMESPACE -l app=service-a -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o True | wc -l)
    check "Service A pods are ready" "[ $READY_A -eq $SERVICE_A_PODS ]"
fi

if [ $SERVICE_B_PODS -gt 0 ]; then
    READY_B=$(kubectl get pods -n $NAMESPACE -l app=service-b -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o True | wc -l)
    check "Service B pods are ready" "[ $READY_B -eq $SERVICE_B_PODS ]"
fi

# Validate Services
title "Validating Kubernetes Services"

check "Service A ClusterIP service exists" "kubectl get service service-a -n $NAMESPACE > /dev/null 2>&1"
check "Service B ClusterIP service exists" "kubectl get service service-b -n $NAMESPACE > /dev/null 2>&1"
check "Service A LoadBalancer service exists" "kubectl get service service-a-loadbalancer -n $NAMESPACE > /dev/null 2>&1"
check "Service B LoadBalancer service exists" "kubectl get service service-b-loadbalancer -n $NAMESPACE > /dev/null 2>&1"

# Check service endpoints
if kubectl get service service-a -n $NAMESPACE > /dev/null 2>&1; then
    ENDPOINTS_A=$(kubectl get endpoints service-a -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
    check "Service A has endpoints" "[ $ENDPOINTS_A -gt 0 ]"
fi

if kubectl get service service-b -n $NAMESPACE > /dev/null 2>&1; then
    ENDPOINTS_B=$(kubectl get endpoints service-b -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
    check "Service B has endpoints" "[ $ENDPOINTS_B -gt 0 ]"
fi

# Validate External Load Balancer IPs
title "Validating External Load Balancer Access"

# Get LoadBalancer external IPs
EXTERNAL_IP_A=""
EXTERNAL_IP_B=""

if kubectl get service service-a-loadbalancer -n $NAMESPACE > /dev/null 2>&1; then
    EXTERNAL_IP_A=$(kubectl get service service-a-loadbalancer -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP_A" ] && [ "$EXTERNAL_IP_A" != "null" ]; then
        check "Service A LoadBalancer has external IP" "[ -n '$EXTERNAL_IP_A' ]"
        log "Service A external IP: $EXTERNAL_IP_A"
    else
        check "Service A LoadBalancer has external IP" "false"
    fi
fi

if kubectl get service service-b-loadbalancer -n $NAMESPACE > /dev/null 2>&1; then
    EXTERNAL_IP_B=$(kubectl get service service-b-loadbalancer -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$EXTERNAL_IP_B" ] && [ "$EXTERNAL_IP_B" != "null" ]; then
        check "Service B LoadBalancer has external IP" "[ -n '$EXTERNAL_IP_B' ]"
        log "Service B external IP: $EXTERNAL_IP_B"
    else
        check "Service B LoadBalancer has external IP" "false"
    fi
fi

# Validate Ingress
title "Validating Ingress Configuration"

check "Ingress resource exists" "kubectl get ingress infra-gke-ingress -n $NAMESPACE > /dev/null 2>&1"

if kubectl get ingress infra-gke-ingress -n $NAMESPACE > /dev/null 2>&1; then
    INGRESS_IP=$(kubectl get ingress infra-gke-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    if [ -n "$INGRESS_IP" ] && [ "$INGRESS_IP" != "null" ]; then
        check "Ingress has external IP assigned" "[ -n '$INGRESS_IP' ]"
        log "Ingress external IP: $INGRESS_IP"
    else
        warn "Ingress external IP not yet assigned (may take several minutes)"
    fi

    check "Ingress has correct backend services" "kubectl get ingress infra-gke-ingress -n $NAMESPACE -o yaml | grep -q 'service-a'"
fi

# Validate External Connectivity
title "Validating External Connectivity"

if [ -n "$EXTERNAL_IP_A" ] && [ "$EXTERNAL_IP_A" != "null" ]; then
    log "Testing Service A external connectivity..."
    if curl -s --max-time 30 "http://$EXTERNAL_IP_A/api/v1/health" > /dev/null 2>&1; then
        check "Service A external health endpoint is accessible" "true"

        # Test specific endpoints
        if curl -s --max-time 10 "http://$EXTERNAL_IP_A/api/v1/health/live" | grep -q "ok\|healthy\|status.*ok" 2>/dev/null; then
            check "Service A liveness endpoint responds correctly" "true"
        else
            check "Service A liveness endpoint responds correctly" "false"
        fi

        if curl -s --max-time 10 "http://$EXTERNAL_IP_A/api/v1/health/ready" | grep -q "ok\|ready\|status.*ok" 2>/dev/null; then
            check "Service A readiness endpoint responds correctly" "true"
        else
            check "Service A readiness endpoint responds correctly" "false"
        fi
    else
        check "Service A external health endpoint is accessible" "false"
    fi
else
    warn "Service A external IP not available - skipping external connectivity tests"
fi

if [ -n "$EXTERNAL_IP_B" ] && [ "$EXTERNAL_IP_B" != "null" ]; then
    log "Testing Service B external connectivity..."
    if curl -s --max-time 30 "http://$EXTERNAL_IP_B/api/v1/health" > /dev/null 2>&1; then
        check "Service B external health endpoint is accessible" "true"

        # Test specific endpoints
        if curl -s --max-time 10 "http://$EXTERNAL_IP_B/api/v1/health/live" | grep -q "ok\|healthy\|status.*ok" 2>/dev/null; then
            check "Service B liveness endpoint responds correctly" "true"
        else
            check "Service B liveness endpoint responds correctly" "false"
        fi

        if curl -s --max-time 10 "http://$EXTERNAL_IP_B/api/v1/health/ready" | grep -q "ok\|ready\|status.*ok" 2>/dev/null; then
            check "Service B readiness endpoint responds correctly" "true"
        else
            check "Service B readiness endpoint responds correctly" "false"
        fi
    else
        check "Service B external health endpoint is accessible" "false"
    fi
else
    warn "Service B external IP not available - skipping external connectivity tests"
fi

# Validate Internal Service Discovery
title "Validating Internal Service Discovery & Communication"

log "Testing internal service discovery with temporary test pod..."

# Create a temporary test pod for internal connectivity tests
kubectl run test-connectivity-$$ \
    --image=alpine/curl:8.10.1 \
    --rm -i --restart=Never \
    --timeout=60s \
    -n $NAMESPACE \
    -- /bin/sh -c "
echo 'Testing Service A internal DNS resolution...'
if nslookup service-a.${NAMESPACE}.svc.cluster.local > /dev/null 2>&1; then
    echo 'Service A DNS resolution: SUCCESS'
    if curl -s --max-time 10 http://service-a.${NAMESPACE}.svc.cluster.local/api/v1/health > /dev/null 2>&1; then
        echo 'Service A internal connectivity: SUCCESS'
    else
        echo 'Service A internal connectivity: FAILED'
    fi
else
    echo 'Service A DNS resolution: FAILED'
fi

echo 'Testing Service B internal DNS resolution...'
if nslookup service-b.${NAMESPACE}.svc.cluster.local > /dev/null 2>&1; then
    echo 'Service B DNS resolution: SUCCESS'
    if curl -s --max-time 10 http://service-b.${NAMESPACE}.svc.cluster.local/api/v1/health > /dev/null 2>&1; then
        echo 'Service B internal connectivity: SUCCESS'
    else
        echo 'Service B internal connectivity: FAILED'
    fi
else
    echo 'Service B DNS resolution: FAILED'
fi

echo 'Testing cross-service communication...'
if curl -s --max-time 10 http://service-a.${NAMESPACE}.svc.cluster.local/api/v1/health > /dev/null 2>&1 && curl -s --max-time 10 http://service-b.${NAMESPACE}.svc.cluster.local/api/v1/health > /dev/null 2>&1; then
    echo 'Cross-service communication: SUCCESS'
else
    echo 'Cross-service communication: FAILED'
fi
" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *"Service A DNS resolution: SUCCESS"*)
            check "Service A internal DNS resolution" "true"
            ;;
        *"Service A DNS resolution: FAILED"*)
            check "Service A internal DNS resolution" "false"
            ;;
        *"Service A internal connectivity: SUCCESS"*)
            check "Service A internal connectivity" "true"
            ;;
        *"Service A internal connectivity: FAILED"*)
            check "Service A internal connectivity" "false"
            ;;
        *"Service B DNS resolution: SUCCESS"*)
            check "Service B internal DNS resolution" "true"
            ;;
        *"Service B DNS resolution: FAILED"*)
            check "Service B internal DNS resolution" "false"
            ;;
        *"Service B internal connectivity: SUCCESS"*)
            check "Service B internal connectivity" "true"
            ;;
        *"Service B internal connectivity: FAILED"*)
            check "Service B internal connectivity" "false"
            ;;
        *"Cross-service communication: SUCCESS"*)
            check "Cross-service communication works" "true"
            ;;
        *"Cross-service communication: FAILED"*)
            check "Cross-service communication works" "false"
            ;;
        *)
            log "$line"
            ;;
    esac
done

# Validate Resource Utilization
title "Validating Resource Utilization"

log "Checking pod resource usage..."
if command -v kubectl top >/dev/null 2>&1; then
    if kubectl top pods -n $NAMESPACE >/dev/null 2>&1; then
        check "Pod metrics are available" "true"
        log "Current pod resource usage:"
        kubectl top pods -n $NAMESPACE 2>/dev/null || warn "Unable to retrieve pod metrics"
    else
        check "Pod metrics are available" "false"
        warn "Metrics server may not be available or still starting"
    fi
else
    warn "kubectl top command not available - skipping resource utilization checks"
fi

# Validate Security Configuration
title "Validating Security Configuration"

# Check security contexts
SERVICE_A_SEC_CONTEXT=$(kubectl get deployment service-a -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null)
SERVICE_B_SEC_CONTEXT=$(kubectl get deployment service-b -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].securityContext.runAsNonRoot}' 2>/dev/null)

check "Service A runs as non-root user" "[ '$SERVICE_A_SEC_CONTEXT' = 'true' ]"
check "Service B runs as non-root user" "[ '$SERVICE_B_SEC_CONTEXT' = 'true' ]"

# Check image pull policies
SERVICE_A_PULL_POLICY=$(kubectl get deployment service-a -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}' 2>/dev/null)
SERVICE_B_PULL_POLICY=$(kubectl get deployment service-b -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}' 2>/dev/null)

check "Service A has proper image pull policy" "[ '$SERVICE_A_PULL_POLICY' = 'Always' ] || [ '$SERVICE_A_PULL_POLICY' = 'IfNotPresent' ]"
check "Service B has proper image pull policy" "[ '$SERVICE_B_PULL_POLICY' = 'Always' ] || [ '$SERVICE_B_PULL_POLICY' = 'IfNotPresent' ]"

# Display Results
title "Validation Results"

echo ""
echo "📊 Validation Summary:"
echo "  Total Checks: $CHECKS_TOTAL"
echo "  Passed: $CHECKS_PASSED"
echo "  Failed: $CHECKS_FAILED"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    log "🎉 All validation checks passed!"
    echo ""
    echo "✅ Phase 4 validation completed successfully!"
    echo ""
    echo "📋 What's been validated:"
    echo "  • GKE deployments with proper replicas and readiness"
    echo "  • Container images in Artifact Registry"
    echo "  • Internal ClusterIP services with endpoints"
    echo "  • External LoadBalancer services with public IPs"
    echo "  • Basic ingress configuration for path-based routing"
    echo "  • External connectivity via LoadBalancer IPs"
    echo "  • Internal service discovery and DNS resolution"
    echo "  • Cross-service communication within the cluster"
    echo "  • Health check endpoints (/health, /live, /ready)"
    echo "  • Security configurations (non-root users, proper contexts)"
    echo ""
    echo "🌐 Your services are accessible at:"
    if [ -n "$EXTERNAL_IP_A" ] && [ "$EXTERNAL_IP_A" != "null" ]; then
        echo "  Service A: http://$EXTERNAL_IP_A"
    fi
    if [ -n "$EXTERNAL_IP_B" ] && [ "$EXTERNAL_IP_B" != "null" ]; then
        echo "  Service B: http://$EXTERNAL_IP_B"
    fi
    echo ""
    echo "🚀 Ready to proceed to Phase 5: Basic Observability"
    echo ""
    echo "📝 To monitor your deployment:"
    echo "  kubectl get all -n $NAMESPACE"
    echo "  kubectl logs -f deployment/service-a -n $NAMESPACE"
    echo "  kubectl logs -f deployment/service-b -n $NAMESPACE"

    exit 0
else
    error "❌ $CHECKS_FAILED validation check(s) failed!"
    echo ""
    echo "🔧 Common issues and solutions:"
    echo ""
    echo "📋 If LoadBalancer IPs are not assigned:"
    echo "  • Wait a few more minutes for GCP to provision external IPs"
    echo "  • Check GCP quotas and ensure LoadBalancer quota is available"
    echo "  • Verify cluster has proper permissions for LoadBalancer creation"
    echo ""
    echo "📋 If pods are not ready:"
    echo "  • Check pod logs: kubectl logs -l app=service-a -n $NAMESPACE"
    echo "  • Verify container images were pushed correctly"
    echo "  • Check resource limits and cluster capacity"
    echo ""
    echo "📋 If health checks fail:"
    echo "  • Verify applications are listening on correct ports (3000, 3001)"
    echo "  • Check application startup logs for errors"
    echo "  • Ensure health endpoints are properly implemented"
    echo ""
    echo "🔧 Re-run this validation script after fixing issues."

    exit 1
fi
