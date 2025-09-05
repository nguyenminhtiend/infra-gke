#!/usr/bin/env bash
set -euo pipefail

# Purpose: Apply AppProject and root Application to the cluster.
# Requires: kubectl context pointing to your GKE Autopilot cluster, Argo CD installed (Phase 3).

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ARGCD_DIR="$ROOT_DIR/argocd"
NAMESPACE=${ARGOCD_NAMESPACE:-argocd}

echo "Applying AppProject (apps) in namespace $NAMESPACE..."
kubectl apply -n "$NAMESPACE" -f "$ARGCD_DIR/projects/apps-project.yaml"

echo "Applying root Application (root-apps) in namespace $NAMESPACE..."
kubectl apply -n "$NAMESPACE" -f "$ARGCD_DIR/apps/root-apps.yaml"

echo "Applied. Argo CD will now discover child Applications under argocd/apps."

