#!/usr/bin/env bash
set -euo pipefail

# Writes infra/terraform/terraform.tfvars from env vars for reproducibility.
# Required:
#   PROJECT_ID, REGION, GITHUB_ORG, GITHUB_REPO
# Optional:
#   WIF_POOL_ID (default: gh-pool)
#   WIF_PROVIDER_ID (default: gh-provider)
#   GITHUB_ALLOWED_REF (default: refs/heads/main)

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/infra/terraform"

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${REGION:?REGION is required}"
: "${GITHUB_ORG:?GITHUB_ORG is required}"
: "${GITHUB_REPO:?GITHUB_REPO is required}"

WIF_POOL_ID=${WIF_POOL_ID:-gh-pool}
WIF_PROVIDER_ID=${WIF_PROVIDER_ID:-gh-provider}
GITHUB_ALLOWED_REF=${GITHUB_ALLOWED_REF:-refs/heads/main}

mkdir -p "$TF_DIR"
cat > "$TF_DIR/terraform.tfvars" <<EOF
project_id = "${PROJECT_ID}"
region     = "${REGION}"

wif_pool_id        = "${WIF_POOL_ID}"
wif_provider_id    = "${WIF_PROVIDER_ID}"
github_org         = "${GITHUB_ORG}"
github_repo        = "${GITHUB_REPO}"
github_allowed_ref = "${GITHUB_ALLOWED_REF}"
EOF

echo "Wrote $TF_DIR/terraform.tfvars"

