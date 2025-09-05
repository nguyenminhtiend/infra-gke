#!/usr/bin/env bash
set -euo pipefail

# Purpose: Write/update Argo CD GitOps manifests for Phase 4 with latest chart versions.
# - Detect repo URL from env or git
# - Resolve latest Helm chart versions for podinfo and nginx
# - Substitute placeholders in YAMLs

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ARGCD_DIR="$ROOT_DIR/argocd"

# Inputs (optional):
#   GIT_REPO_URL: full https git URL to this repo (e.g., https://github.com/<org>/<repo>.git)
#   BRANCH: Git revision for root app (default: main)

GIT_REPO_URL=${GIT_REPO_URL:-}
BRANCH=${BRANCH:-main}

# Try to infer repo URL if not provided
if [[ -z "$GIT_REPO_URL" ]]; then
  if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_REPO_URL=$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null || true)
  fi
fi

if [[ -z "$GIT_REPO_URL" ]]; then
  echo "ERROR: GIT_REPO_URL is not set and could not be inferred from git." >&2
  echo "Set GIT_REPO_URL or configure git remote 'origin'." >&2
  exit 1
fi

# Normalize repo URL for Argo CD (strip .git suffix)
GIT_REPO_URL_NOSUFFIX=${GIT_REPO_URL%.git}

# Ensure directories exist
mkdir -p "$ARGCD_DIR/projects" "$ARGCD_DIR/apps"

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

# Add/Update repos
helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
helm repo add podinfo https://stefanprodan.github.io/podinfo >/dev/null 2>&1 || true
helm repo update >/dev/null

# Get latest non-deprecated versions (sorted by version desc already by helm)
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
  echo "Example: NGINX_CHART_VERSION=18.3.3 PODINFO_CHART_VERSION=6.6.4 bash scripts/phase4-write-manifests.sh" >&2
  exit 1
fi

echo "bitnami/nginx -> $LATEST_NGINX"
echo "stefanprodan/podinfo -> $LATEST_PODINFO"

# Substitute placeholders in templates
sed -i'' -e "s#REPO_URL_PLACEHOLDER#$GIT_REPO_URL_NOSUFFIX#g" "$ARGCD_DIR/projects/apps-project.yaml"
sed -i'' -e "s#REPO_URL_PLACEHOLDER#$GIT_REPO_URL_NOSUFFIX#g" -e "s#targetRevision: .*#targetRevision: $BRANCH#g" "$ARGCD_DIR/apps/root-apps.yaml"
sed -i'' -e "s#CHART_VERSION_PODINFO_PLACEHOLDER#$LATEST_PODINFO#g" "$ARGCD_DIR/apps/podinfo-app.yaml"
sed -i'' -e "s#CHART_VERSION_NGINX_PLACEHOLDER#$LATEST_NGINX#g" "$ARGCD_DIR/apps/nginx-app.yaml"

echo "Phase 4 manifests updated with latest chart versions and repo URL:"
echo "- $ARGCD_DIR/projects/apps-project.yaml"
echo "- $ARGCD_DIR/apps/root-apps.yaml"
echo "- $ARGCD_DIR/apps/podinfo-app.yaml"
echo "- $ARGCD_DIR/apps/nginx-app.yaml"
