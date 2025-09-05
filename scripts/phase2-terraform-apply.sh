#!/usr/bin/env bash
set -euo pipefail

# Apply Phase 2 changes (GKE Autopilot cluster)

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/infra/terraform"

pushd "$TF_DIR" >/dev/null
PLAN_FILE="plan-phase2.tfplan"
if [[ ! -f "$PLAN_FILE" ]]; then
  echo "No $PLAN_FILE found. Running plan first..."
  terraform init -upgrade -input=false >/dev/null
  terraform plan -out="$PLAN_FILE"
fi
terraform apply -input=false "$PLAN_FILE"
popd >/dev/null

echo "Phase 2 apply completed."

