#!/usr/bin/env bash
set -euo pipefail

# Verify the Autopilot cluster is reachable and healthy enough
# Required env: PROJECT_ID

: "${PROJECT_ID:?PROJECT_ID is required}"

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

"$ROOT_DIR/scripts/phase2-get-credentials.sh"

echo "Listing nodes..."
kubectl get nodes -o wide

echo "Listing pods in kube-system (sample)..."
kubectl get pods -n kube-system -o wide --no-headers | head -n 20 || true

echo "Cluster info:"
kubectl cluster-info

echo "Phase 2 verification completed."

