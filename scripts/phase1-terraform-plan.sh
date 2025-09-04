#!/usr/bin/env bash
set -euo pipefail

# Creates a Terraform plan for Phase 1 (WIF + SA bindings)
# Requires terraform.tfvars (use scripts/phase1-write-tfvars.sh)

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/infra/terraform"

pushd "$TF_DIR" >/dev/null
terraform plan -out=plan.tfplan
popd >/dev/null

echo "Plan written to infra/terraform/plan.tfplan"

