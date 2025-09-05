#!/usr/bin/env bash
set -euo pipefail

# Verify Argo CD installation status
# Required env: PROJECT_ID
# Optional env: NAMESPACE (default: argocd)

: "${PROJECT_ID:?PROJECT_ID is required}"
NAMESPACE=${NAMESPACE:-argocd}

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

"$ROOT_DIR/scripts/phase2-get-credentials.sh"

echo "Checking Argo CD namespace ($NAMESPACE) resources..."
kubectl get ns "$NAMESPACE" -o jsonpath='{.metadata.name}' >/dev/null 2>&1 || {
  echo "Namespace $NAMESPACE not found. Did Phase 3 apply succeed?" >&2
  exit 1
}

echo "Pods:"; kubectl -n "$NAMESPACE" get pods -o wide || true
echo "Services:"; kubectl -n "$NAMESPACE" get svc || true

echo "Waiting for argo-cd server deployment to be Ready..."
kubectl -n "$NAMESPACE" rollout status deploy/argo-cd-argocd-server --timeout=5m

echo "Initial admin password:"
"$ROOT_DIR/scripts/phase3-get-admin-password.sh" || true

echo "You can now port-forward with:"
echo "  bash scripts/phase3-port-forward-argocd.sh"
echo "Then open: http://localhost:8080 (username: admin)"

echo "Phase 3 verification completed."

