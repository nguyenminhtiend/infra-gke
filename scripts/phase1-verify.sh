#!/usr/bin/env bash
set -euo pipefail

# Verifies key Phase 1 resources exist using gcloud
# Required env: PROJECT_ID

: "${PROJECT_ID:?PROJECT_ID is required}"
WIF_POOL_ID=${WIF_POOL_ID:-gh-pool}
WIF_PROVIDER_ID=${WIF_PROVIDER_ID:-gh-provider}

echo "Verifying WIF Pool..."
gcloud iam workload-identity-pools describe "$WIF_POOL_ID" \
  --project "$PROJECT_ID" --location=global --format='get(name)'

echo "Verifying WIF Provider..."
gcloud iam workload-identity-pools providers describe "$WIF_PROVIDER_ID" \
  --project "$PROJECT_ID" --location=global --workload-identity-pool "$WIF_POOL_ID" \
  --format='get(name)'

SA_EMAIL="tf-ci@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Verifying CI Service Account: $SA_EMAIL"
gcloud iam service-accounts describe "$SA_EMAIL" --project "$PROJECT_ID" --format='get(email)'

echo "Checking SA IAM policy contains workloadIdentityUser..."
gcloud iam service-accounts get-iam-policy "$SA_EMAIL" --project "$PROJECT_ID" \
  --format=json | jq -r '.bindings[] | select(.role=="roles/iam.workloadIdentityUser") | .members[]' || true

echo "Phase 1 verification completed."

