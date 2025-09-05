#!/usr/bin/env bash
set -euo pipefail

# Purpose: Verify Argo CD applications created by Phase 4 are present and report status.

NAMESPACE=${ARGOCD_NAMESPACE:-argocd}

echo "Listing Argo CD Applications in namespace $NAMESPACE..."
kubectl get applications.argoproj.io -n "$NAMESPACE" || true

echo
echo "Describing root application (root-apps)..."
kubectl get application.argoproj.io/root-apps -n "$NAMESPACE" -o jsonpath='{.status.sync.status}{"\n"}' || true
kubectl get application.argoproj.io/root-apps -n "$NAMESPACE" -o jsonpath='{.status.health.status}{"\n"}' || true

echo
echo "If argocd CLI is installed and you are logged in, you can also run:"
echo "  argocd app list"
echo "  argocd app get root-apps"

