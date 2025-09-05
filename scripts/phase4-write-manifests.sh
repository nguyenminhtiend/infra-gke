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

# Always update repo URL/branch placeholders first (does not require network)
if grep -q 'REPO_URL_PLACEHOLDER' "$ARGCD_DIR/projects/apps-project.yaml" 2>/dev/null; then
  sed -i'' -e "s#REPO_URL_PLACEHOLDER#$GIT_REPO_URL_NOSUFFIX#g" "$ARGCD_DIR/projects/apps-project.yaml"
fi
if grep -q 'REPO_URL_PLACEHOLDER' "$ARGCD_DIR/apps/root-apps.yaml" 2>/dev/null; then
  sed -i'' -e "s#REPO_URL_PLACEHOLDER#$GIT_REPO_URL_NOSUFFIX#g" -e "s#targetRevision: .*#targetRevision: $BRANCH#g" "$ARGCD_DIR/apps/root-apps.yaml"
else
  # Still ensure branch is set
  sed -i'' -e "s#targetRevision: .*#targetRevision: $BRANCH#g" "$ARGCD_DIR/apps/root-apps.yaml" || true
fi

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
  echo "NOTE: Skipping chart version updates; could not resolve versions and no overrides provided." >&2
  echo "      You can run again with: NGINX_CHART_VERSION=<x.y.z> PODINFO_CHART_VERSION=<a.b.c>" >&2
else
  echo "bitnami/nginx -> $LATEST_NGINX"
  echo "stefanprodan/podinfo -> $LATEST_PODINFO"
  sed -i'' -e "s#CHART_VERSION_PODINFO_PLACEHOLDER#$LATEST_PODINFO#g" "$ARGCD_DIR/apps/podinfo-app.yaml"
  sed -i'' -e "s#CHART_VERSION_NGINX_PLACEHOLDER#$LATEST_NGINX#g" "$ARGCD_DIR/apps/nginx-app.yaml"
fi

echo "Phase 4 manifests updated (repo URL/branch always set; charts updated if available):"
echo "- $ARGCD_DIR/projects/apps-project.yaml"
echo "- $ARGCD_DIR/apps/root-apps.yaml"
echo "- $ARGCD_DIR/apps/podinfo-app.yaml"
echo "- $ARGCD_DIR/apps/nginx-app.yaml"
