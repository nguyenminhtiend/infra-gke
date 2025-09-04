#!/usr/bin/env bash
set -euo pipefail

# Initializes Terraform backend using GCS bucket/prefix and locks provider versions.
# Required env:
#   PROJECT_ID, REGION
#   TF_STATE_BUCKET (existing, versioned) — created in Phase 0
# Optional:
#   TF_STATE_PREFIX (default: infra/terraform/state)

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/infra/terraform"

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
TF_STATE_PREFIX=${TF_STATE_PREFIX:-infra/terraform/state}

pushd "$TF_DIR" >/dev/null

terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=${TF_STATE_PREFIX}"

terraform fmt -recursive
terraform validate

popd >/dev/null

echo "Terraform initialized with backend bucket=${TF_STATE_BUCKET} prefix=${TF_STATE_PREFIX}"

