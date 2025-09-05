# Minimal Argo CD on GKE Autopilot with Terraform, Helm, and GitHub Actions — Learning Plan

## Objectives
- Learn Argo CD deeply using a minimal yet best‑practice setup.
- Provision GKE Autopilot with Terraform and bootstrap Argo CD via Helm.
- Manage two sample applications via GitOps (Argo CD Applications) from a GitHub repo.
- Use GitHub Actions with Workload Identity Federation (no long‑lived keys) to apply infra.

## Scope & Assumptions
- Single GCP project and one GKE Autopilot cluster (regional) for `dev`.
- No public ingress required for apps/UI (access via port‑forward) to stay minimal.
- Git repository holds infra (Terraform), Argo CD configs, and app Helm values.
- Two sample apps deployed via Helm: `podinfo` and `nginx`.
- Best practices favored where low overhead (e.g., WIF, pinned versions, AppProject boundaries).

## High‑Level Architecture
- GitHub repo (monorepo):
  - Terraform creates GKE Autopilot and installs Argo CD via Helm provider.
  - Argo CD is the single deployment controller, pulling desired state from `main`.
  - App of Apps pattern defines two Applications (`podinfo`, `nginx`) in their own namespaces.
- GitHub Actions:
  - Infra pipeline: plans/applies Terraform using GCP Workload Identity Federation.
  - App pipeline (optional): lint Helm values and validate manifests (no direct cluster writes).

## Repository Layout (proposed)
- `infra/terraform/` — GCP project, WIF, GKE Autopilot, Argo CD (Helm release), outputs.
- `argocd/` — AppProject, App of Apps root, Applications for `podinfo` and `nginx`.
- `apps/podinfo/` — Helm values and docs (using upstream chart).
- `apps/nginx/` — Helm values and docs (using upstream chart).
- `.github/workflows/` — `infra.yml` (Terraform), `apps.yml` (lint/validate).

## Phase 0 — Prerequisites & Setup
Goals
- Ensure accounts, tools, and project are ready.

Actions
- Create/choose a GCP project with billing enabled.
- Enable required APIs: Container, IAM, IAM Credentials, Cloud Resource Manager, Artifact Registry (if needed).
- Prepare tooling locally: gcloud, Terraform ≥ 1.5, kubectl, Helm 3, Argo CD CLI (optional).
- Create a remote Terraform state bucket (versioned) and a state lock mechanism (e.g., GCS + Dynamo‑like alt not required; GCS alone is OK for learning).
- Create an empty GitHub repository with default branch `main`.

 Scripts (2025‑ready)
 - Install tools (latest stable): `bash scripts/phase0-install-tools.sh`
 - Bootstrap GCP (enable APIs + TF bucket): `PROJECT_ID="<your-project-id>" TF_STATE_BUCKET_LOCATION="US" TF_STATE_BUCKET="<optional-bucket-name>" bash scripts/phase0-gcp-bootstrap.sh`
 - Verify setup: `bash scripts/phase0-verify.sh`
 - Optional GitHub repo (with GitHub CLI):
   - `gh repo create <owner>/<repo> --public --clone --default-branch main` (or `--private`)
   - `git push -u origin main`

Deliverables
- Project ID, region/zone choices, service enablement confirmed.
- GitHub repo initialized with baseline folders.

Checkpoints
- You can authenticate to GCP locally and list projects.
- GitHub repo exists and is accessible.

## Phase 1 — Terraform Foundation
Goals
- Establish Terraform scaffolding, providers, state backend, and WIF for CI.

Actions
- Configure Terraform backend to use the versioned GCS bucket.
- Define required providers with pinned versions: `google`, `google-beta`, `kubernetes`, `helm`.
- Create a GCP service account (SA) for Terraform to impersonate.
- Set up Workload Identity Federation (WIF):
  - Create a Workload Identity Pool and GitHub OIDC Provider.
  - Bind the Terraform SA to the provider with minimum roles (e.g., container admin for cluster provision, SA token creator for impersonation; scope to project).
- Export outputs required later (e.g., cluster name, location, endpoint, CA).

Deliverables
- Terraform provider auth via WIF (no static keys).
- `infra/terraform/` with backend + providers scaffold and WIF resources.

Checkpoints
 - `terraform init` completes cleanly and backend is configured.
 - WIF issuer and attribute mapping validated (GitHub repo and branch).

 Scripts (2025‑ready)
 - Env vars (required):
   - `PROJECT_ID`, `REGION`, `TF_STATE_BUCKET`, `GITHUB_ORG`, `GITHUB_REPO`
   - Optional: `WIF_POOL_ID=gh-pool`, `WIF_PROVIDER_ID=gh-provider`, `GITHUB_ALLOWED_REF=refs/heads/main`, `TF_STATE_PREFIX=infra/terraform/state`
 - Generate tfvars: `bash scripts/phase1-write-tfvars.sh`
 - Init backend + validate: `bash scripts/phase1-terraform-init.sh`
 - Plan changes: `bash scripts/phase1-terraform-plan.sh`
 - Apply (WIF + CI SA): `bash scripts/phase1-terraform-apply.sh`
 - Verify resources: `PROJECT_ID="<id>" bash scripts/phase1-verify.sh`
 - Note: CI Service Account ID is `terraform-ci` (must be 6–30 chars, start with a letter, only lowercase letters, digits, and hyphens, and end with a letter or digit).

 Notes
 - Provider versions are pinned (google/google-beta 5.43.1, kubernetes 2.32.0, helm 2.13.2) and Terraform `>= 1.6, < 2.0`. Update as needed.
 - Backend is passed via `-backend-config` to support different buckets/prefixes per environment.

## Phase 2 — Provision GKE Autopilot
Goals
- Create a minimal, secure GKE Autopilot cluster ready for GitOps.

Actions
- Create a regional Autopilot cluster (stable release channel) with Workload Identity enabled.
- Configure basic cluster metadata: project labels, cost center, environment labels (`env=dev`).
- Output kubeconfig connection details via Terraform outputs.

Deliverables
- Regional Autopilot cluster running and reachable.

Checkpoints
- You can connect to the cluster and list nodes/pods.

## Phase 3 — Install Argo CD (via Helm, managed by Terraform)
Goals
- Install Argo CD reproducibly with Terraform’s Helm provider and minimal configuration.

Actions
- Create namespace `argocd`.
- Install `argo-cd` Helm chart with pinned version and values aligned to Autopilot:
  - Service type ClusterIP for server (UI via port‑forward for learning).
  - Enable recommended resource requests/limits, readiness/liveness probes.
  - Disable external dex/SSO initially; use local admin for simplicity.
  - Set RBAC policy to default; later phases may customize.
- Optionally enable Argo CD Notifications (skip for minimal setup).

Deliverables
- Argo CD installed in `argocd` namespace and healthy.

Checkpoints
- Argo CD workloads show Healthy/Synced.
- You can port‑forward to the UI and log in with the initial admin password from the Argo CD secret.

 Scripts (2025‑ready)
 - Env vars (required): `PROJECT_ID`
 - Env vars (optional): `ARGOCD_NAMESPACE=argocd`, `ARGOCD_CHART_VERSION=<chart-version>`
 - Pin latest chart in tfvars: `bash scripts/phase3-write-argocd-tfvars.sh`
 - Plan Helm install: `bash scripts/phase3-terraform-plan.sh`
 - Apply Helm install: `bash scripts/phase3-terraform-apply.sh`
 - Verify install + get password: `PROJECT_ID="<id>" bash scripts/phase3-verify.sh`
 - Port‑forward UI: `bash scripts/phase3-port-forward-argocd.sh` (default http://localhost:8080)

## Phase 4 — GitOps Structure (App of Apps + AppProject)
Goals
- Define Argo CD projects and applications to manage two apps declaratively.

Actions
- Create an `AppProject` (e.g., `apps`) that:
  - Restricts source repos to your GitHub repo.
  - Restricts destinations to the current cluster.
  - Allows namespaces `podinfo`, `nginx` (and `argocd` for bootstrap if needed).
- Adopt the App of Apps pattern:
  - A root Application (e.g., `root-apps`) that points to `argocd/` directory where child Applications live.
- Define two child Applications:
  - `podinfo` → upstream Helm chart, pinned chart version, namespace `podinfo`, automated sync (prune + self‑heal).
  - `nginx` → upstream Helm chart, pinned chart version, namespace `nginx`, automated sync (prune + self‑heal).
- Define namespaces as part of app manifests or via a lightweight `bootstrap` manifest to ensure namespace creation precedes app sync (sync waves or hooks can be used conceptually; keep minimal by including Namespace manifests).

Deliverables
- `argocd/` directory with AppProject, root Application, and two Application manifests.

Checkpoints
- Argo CD shows three Applications (root + two apps) Healthy/Synced.
- Namespaces `podinfo` and `nginx` exist with app workloads running.

## Phase 5 — Application Configuration (Helm Values)
Goals
- Keep app configuration minimal but deterministic and Autopilot‑friendly.

Actions
- For `podinfo` and `nginx`, create a small values file each under `apps/<name>/`:
  - Pin image tags to immutable versions.
  - Set low resource requests/limits compatible with Autopilot defaults.
  - Expose service as ClusterIP; skip Ingress for now.
  - Add basic labels/annotations (`app.kubernetes.io/*`, `argocd.argoproj.io/instance`).
- Wire Applications to use these values files via Helm parameters in the Application spec.

Deliverables
- Two value sets committed and referenced by the Applications.

Checkpoints
- Argo CD diff shows only expected changes when values are updated.

## Phase 6 — GitHub Actions (CI) Workflows
Goals
- Automate infrastructure changes; validate app changes without direct cluster writes.

Actions
- `infra.yml` (Terraform):
  - Triggers: PR (plan), push to `main` (apply), workflow_dispatch.
  - Steps: setup auth via WIF, Terraform fmt/validate, plan (PR comment), apply on `main`.
  - Concurrency key to avoid overlapping applies.
- `apps.yml` (optional but good practice):
  - Triggers: PRs touching `argocd/**` or `apps/**`.
  - Steps: Helm lint and manifest validation (e.g., kubeconform) against a pinned K8s schema.
  - No cluster credentials used; Argo CD will reconcile after merge to `main`.

Deliverables
- Two workflows under `.github/workflows/` with WIF configured for infra.

Checkpoints
- PRs show Terraform plan output.
- Merging to `main` updates cluster and Argo CD reconciles to desired state.

## Phase 7 — Verification & Learning Exercises
Goals
- Build deep understanding of Argo CD reconciliation and operations.

Exercises
- Drift detection: manually change a replica count in the cluster; observe Argo CD self‑heal.
- Pruning: remove a resource from Git; confirm Argo CD prunes it.
- Sync waves: ensure Namespace manifests apply before apps (demonstrate ordering conceptually).
- Rollbacks: commit a bad values change; use Argo CD UI/CLI to rollback.
- Health statuses: break readiness probe; observe Degraded state; fix via Git commit.
- Pause sync: set syncPolicy to manual temporarily; trigger manual sync; re‑enable automation.

Deliverables
- Documented observations and screenshots (optional) to cement learning.

Checkpoints
- Comfortable interpreting Argo CD app statuses, diffs, and events.

## Phase 8 — Hardening & Nice‑to‑Haves (Optional)
Goals
- Incrementally introduce best practices beyond the minimal setup.

Options
- Access:
  - Add an Ingress for Argo CD UI with Google‑managed certs and IAP or OAuth proxy.
  - Enable SSO (GitHub/G Suite) via Dex; set least‑privilege RBAC roles.
- Security:
  - Move admin password to a Secret Manager + external‑secrets flow.
  - Enable Argo CD Notifications for sync failures to Slack/Email.
  - Constrain Argo CD via AppProject cluster/namespace/resource white‑lists.
- Delivery:
  - Introduce environments (e.g., `dev`, `stg`) with separate folders or branches.
  - Evaluate ApplicationSet for multi‑env or multi‑cluster.
  - Add Argo CD Image Updater for automatic image tag bumps (learning exercise).
- Observability:
  - Add metrics scraping and dashboards (Prometheus/Grafana) for Argo CD and apps.

## Clean‑Up
- Remove Applications and verify Argo CD prunes resources.
- Uninstall Argo CD Helm release via Terraform.
- Destroy GKE cluster via Terraform.
- Optionally delete WIF provider and TF state bucket.

## Best‑Practice Summary (kept minimal)
- Pin all versions (Terraform providers, Helm charts, container images).
- Use WIF; avoid static service account keys.
- Separate concerns: Terraform for infra and Argo CD install; Argo CD for apps.
- Use AppProject to constrain sources/destinations; one namespace per app.
- Enable automated sync with prune/self‑heal for a true GitOps loop.
- Keep services internal (ClusterIP) unless there is a clear need.

## What You’ll Learn
- How Argo CD continuously reconciles desired vs. live state.
- How Git becomes the single source of truth for apps.
- How Terraform bootstraps clusters and Argo CD repeatably.
- How CI surfaces safe plans while CD happens via pull‑based GitOps.

---

### Quick Phase Checklist
1) Prereqs ready (project, APIs, tools, repo)
2) Terraform backend + WIF configured
3) GKE Autopilot cluster created
4) Argo CD installed (Helm via Terraform)
5) AppProject + App of Apps defined
6) Two apps (`podinfo`, `nginx`) syncing
7) CI workflows active (plan/apply + lint)
8) Exercises completed; optional hardening explored
