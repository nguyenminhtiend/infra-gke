#!/usr/bin/env bash
set -euo pipefail

# Prints the Argo CD initial admin password from the secret
# Optional env: NAMESPACE (default: argocd)

NAMESPACE=${NAMESPACE:-argocd}

kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

