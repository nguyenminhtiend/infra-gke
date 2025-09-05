#!/usr/bin/env bash
set -euo pipefail

# Detects latest argo-cd chart version and writes it to terraform.tfvars.
# You can override detection with ARGOC D_CHART_VERSION env var.
# Optional: set ARGOC D_NAMESPACE (default: argocd)

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
TF_DIR="$ROOT_DIR/infra/terraform"

ARGOCD_NAMESPACE=${ARGOCD_NAMESPACE:-argocd}
ARGOCD_CHART_VERSION=${ARGOCD_CHART_VERSION:-}

if [[ -z "${ARGOCD_CHART_VERSION}" ]]; then
  echo "Determining latest argo-cd chart version from argo-helm..."
  helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
  helm repo update >/dev/null
  # List all versions, sort semver, pick highest
  if ! LATEST=$(helm search repo argo/argo-cd --versions | awk 'NR>1 {print $2}' | sort -V | tail -n1); then
    echo "Failed to detect latest chart version. Set ARGOCD_CHART_VERSION explicitly." >&2
    exit 1
  fi
  ARGOCD_CHART_VERSION="$LATEST"
fi

mkdir -p "$TF_DIR"
TFVARS="$TF_DIR/terraform.tfvars"
touch "$TFVARS"

upsert_var() {
  local key="$1"; shift
  local value="$1"; shift
  if grep -qE "^\s*${key}\s*=" "$TFVARS"; then
    # Replace in-place
    sed -i'' -E "s|^\s*${key}\s*=.*|${key} = \"${value}\"|" "$TFVARS"
  else
    echo "${key} = \"${value}\"" >> "$TFVARS"
  fi
}

upsert_var argocd_chart_version "$ARGOCD_CHART_VERSION"
upsert_var argocd_namespace "$ARGOCD_NAMESPACE"

echo "Wrote/updated $TFVARS with:"
echo "  argocd_chart_version = $ARGOCD_CHART_VERSION"
echo "  argocd_namespace     = $ARGOCD_NAMESPACE"
