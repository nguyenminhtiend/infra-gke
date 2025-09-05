#!/usr/bin/env bash
set -euo pipefail

# Fetch kubeconfig for the Autopilot cluster using terraform outputs
# Required env: PROJECT_ID

: "${PROJECT_ID:?PROJECT_ID is required}"

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/infra/terraform"

pushd "$TF_DIR" >/dev/null
CLUSTER_NAME=$(terraform output -raw cluster_name)
CLUSTER_LOCATION=$(terraform output -raw cluster_location)
popd >/dev/null

echo "Getting credentials for $CLUSTER_NAME in $CLUSTER_LOCATION (project $PROJECT_ID)..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region "$CLUSTER_LOCATION" \
  --project "$PROJECT_ID"

echo "Kubeconfig updated. Current context:"
kubectl config current-context

