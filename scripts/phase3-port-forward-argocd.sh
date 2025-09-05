#!/usr/bin/env bash
set -euo pipefail

# Port-forward Argo CD API server locally
# Optional env: NAMESPACE (default: argocd), LOCAL_PORT (default: 8080)

NAMESPACE=${NAMESPACE:-argocd}
LOCAL_PORT=${LOCAL_PORT:-8080}

echo "Port-forwarding Argo CD server on http://localhost:${LOCAL_PORT} ..."
kubectl -n "$NAMESPACE" port-forward svc/argo-cd-argocd-server "${LOCAL_PORT}:80"

