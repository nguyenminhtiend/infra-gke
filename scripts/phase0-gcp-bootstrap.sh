#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf "[phase0-gcp] %s\n" "$*"; }
err() { printf "[phase0-gcp][error] %s\n" "$*" 1>&2; }
has() { command -v "$1" >/dev/null 2>&1; }

PROJECT_ID="${PROJECT_ID:-}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-}"
TF_STATE_BUCKET_LOCATION="${TF_STATE_BUCKET_LOCATION:-US}"

if [ -z "${PROJECT_ID}" ]; then
  err "PROJECT_ID is required. Export PROJECT_ID=<your-gcp-project-id> and re-run."
  exit 1
fi

if [ -z "${TF_STATE_BUCKET}" ]; then
  TF_STATE_BUCKET="${PROJECT_ID}-tf-state"
fi

if ! has gcloud || ! has gsutil; then
  err "gcloud and gsutil are required. Run scripts/phase0-install-tools.sh first."
  exit 1
fi

log "Setting gcloud project to ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}" 1>/dev/null

log "Enabling required APIs"
gcloud services enable \
  container.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  artifactregistry.googleapis.com \
  --project "${PROJECT_ID}" --quiet

log "Ensuring Terraform state bucket gs://${TF_STATE_BUCKET} exists in ${TF_STATE_BUCKET_LOCATION}"
if gsutil ls -b "gs://${TF_STATE_BUCKET}" >/dev/null 2>&1; then
  log "Bucket already exists"
else
  gsutil mb -p "${PROJECT_ID}" -l "${TF_STATE_BUCKET_LOCATION}" -b on "gs://${TF_STATE_BUCKET}"
  gsutil versioning set on "gs://${TF_STATE_BUCKET}"
fi

log "Summary:"
echo "  Project: ${PROJECT_ID}"
echo "  TF State Bucket: gs://${TF_STATE_BUCKET} (${TF_STATE_BUCKET_LOCATION})"
echo "  Enabled APIs: container, iam, iamcredentials, cloudresourcemanager, artifactregistry"

log "You can now configure Terraform backend with this bucket."

