#!/usr/bin/env bash
set -euo pipefail

# Purpose: Refresh child Applications to the latest available chart versions.
# Same logic as write-manifests but only updates chart versions in child app YAMLs.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ARGCD_DIR="$ROOT_DIR/argocd"

echo "Checking dependencies..."
if ! command -v helm >/dev/null 2>&1; then
  echo "ERROR: helm not found. Install helm 3 first." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found. Install jq first." >&2
  exit 1
fi

echo "Resolving latest chart versions (requires network and helm)..."

helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
helm repo add podinfo https://stefanprodan.github.io/podinfo >/dev/null 2>&1 || true
helm repo update >/dev/null

LATEST_NGINX=$(helm search repo bitnami/nginx --versions --output json \
  | jq -r '.[] | select((.name=="bitnami/nginx") and (.deprecated != true)) | .version' \
  | sort -Vr | head -n1)
LATEST_PODINFO=$(helm search repo podinfo/podinfo --versions --output json \
  | jq -r '.[] | select((.name=="podinfo/podinfo") and (.deprecated != true)) | .version' \
  | sort -Vr | head -n1)

if [[ -z "${LATEST_NGINX:-}" || -z "${LATEST_PODINFO:-}" ]]; then
  echo "WARN: Could not resolve latest chart versions via Helm search." >&2
  echo "      Falling back to env overrides if provided." >&2
  LATEST_NGINX=${LATEST_NGINX:-${NGINX_CHART_VERSION:-}}
  LATEST_PODINFO=${LATEST_PODINFO:-${PODINFO_CHART_VERSION:-}}
fi

if [[ -z "${LATEST_NGINX:-}" || -z "${LATEST_PODINFO:-}" ]]; then
  echo "ERROR: Chart versions are empty. Provide NGINX_CHART_VERSION and PODINFO_CHART_VERSION env vars or ensure network access." >&2
  echo "Example: NGINX_CHART_VERSION=18.3.3 PODINFO_CHART_VERSION=6.6.4 bash scripts/phase4-refresh-chart-versions.sh" >&2
  exit 1
fi

sed -i'' -e "s#targetRevision: .*#targetRevision: $LATEST_PODINFO#g" "$ARGCD_DIR/apps/podinfo-app.yaml"
sed -i'' -e "s#targetRevision: .*#targetRevision: $LATEST_NGINX#g" "$ARGCD_DIR/apps/nginx-app.yaml"

echo "Updated chart versions:"
echo "- podinfo -> $LATEST_PODINFO"
echo "- nginx   -> $LATEST_NGINX"
