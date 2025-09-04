#!/usr/bin/env bash
set -euo pipefail

# Applies the previously generated Terraform plan (or applies directly if no plan)

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/infra/terraform"

pushd "$TF_DIR" >/dev/null
if [[ -f plan.tfplan ]]; then
  terraform apply -auto-approve plan.tfplan
else
  terraform apply -auto-approve
fi
popd >/dev/null

echo "Applied Phase 1 Terraform (WIF + CI SA)"

