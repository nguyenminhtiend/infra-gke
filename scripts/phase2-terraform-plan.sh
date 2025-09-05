#!/usr/bin/env bash
set -euo pipefail

# Plan Phase 2 changes (GKE Autopilot cluster)

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/infra/terraform"

pushd "$TF_DIR" >/dev/null
# Ensure providers are on latest allowed by constraints
terraform init -upgrade -input=false >/dev/null
terraform plan -out=plan-phase2.tfplan
popd >/dev/null

echo "Plan written to infra/terraform/plan-phase2.tfplan"

