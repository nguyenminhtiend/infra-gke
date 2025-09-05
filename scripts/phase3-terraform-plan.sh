#!/usr/bin/env bash
set -euo pipefail

# Plan Phase 3 changes (Argo CD via Helm)

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/infra/terraform"

pushd "$TF_DIR" >/dev/null
# Ensure providers are on latest allowed by constraints
terraform init -upgrade -input=false >/dev/null
terraform plan -out=plan-phase3.tfplan
popd >/dev/null

echo "Plan written to infra/terraform/plan-phase3.tfplan"

