#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf "[phase0-verify] %s\n" "$*"; }
warn() { printf "[phase0-verify][warn] %s\n" "$*" 1>&2; }
has() { command -v "$1" >/dev/null 2>&1; }

missing=()
for bin in gcloud terraform kubectl helm; do
  if ! has "$bin"; then
    missing+=("$bin")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  warn "Missing tools: ${missing[*]}"
  warn "Run scripts/phase0-install-tools.sh first."
  exit 1
fi

log "Tool versions:" 
gcloud --version | sed 's/^/[gcloud] /' || true
terraform -version | sed 's/^/[terraform] /' || true
kubectl version --client=true --output=yaml | sed 's/^/[kubectl] /' || true
helm version --short | sed 's/^/[helm] /' || true
if command -v argocd >/dev/null 2>&1; then
  argocd version --client | sed 's/^/[argocd] /' || true
fi

log "Checking gcloud auth and project access"
if ! gcloud auth list --format='value(account)' | grep -q .; then
  warn "No gcloud account logged in. Run: gcloud auth login && gcloud auth application-default login"
  exit 1
fi

log "Listing first 5 projects (verifies access)"
gcloud projects list --format='table(projectId,name,projectNumber)' --limit=5 || true

log "Verify kubectl can connect to a cluster later using:"
echo "  gcloud container clusters get-credentials <NAME> --region <REGION> --project <PROJECT_ID>" 
echo "  kubectl get nodes -owide"

log "OK"

