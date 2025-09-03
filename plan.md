## Phase 0 — Prerequisites & Repo Layout (Planning)

**Deliverables**

- A GCP project with billing on; IAM admin for setup.
- Local tools: gcloud, kubectl, Terraform, Helm, Git, GitHub account.
- Two GitHub repos (or one mono‑repo with folders):

  1. **infra**: Terraform for GKE Autopilot.
  2. **gitops**: Argo CD root (App‑of‑Apps), Helm charts, env configs.

**GitOps repository logical structure (described)**

- A top‑level folder for **clusters** (e.g., `gke-autopilot`) containing the **root application** and Argo CD **Project** definitions.
- An **apps** folder with:

  - `app-a/` — in‑house Helm chart (values for dev/prod).
  - `app-b/` — third‑party chart reference (values for dev/prod).

- An **envs** folder with namespaces and policies for `dev/` and `prod/`.

**Decisions**

- Use **GitHub** (public or private). If private, plan Argo CD repo access via deploy key or PAT.
- Choose the two apps:

  - **App A (in‑house)**: a simple web service chart (your base chart).
  - **App B (third‑party)**: common vendor chart (e.g., NGINX/Redis) aligned to Autopilot limits.

### Phase 0 — Implementation Steps (Do This Now)

1) **Prepare GCP & IAM**
- Create (or choose) a GCP project with billing enabled.
- Ensure you have `Owner` for bootstrap (you can later reduce to least‑privilege). At minimum for Phase 1 you’ll need: `roles/container.admin`, `roles/iam.serviceAccountAdmin`, `roles/iam.serviceAccountKeyAdmin`, `roles/serviceusage.serviceUsageAdmin`, `roles/compute.networkAdmin`.
- Record your identifiers in a local `.env.local` (not committed):
  - `GCP_PROJECT_ID=...`
  - `GCP_REGION=asia-southeast1` (or your choice)
  - `GCP_ZONE=asia-southeast1-a` (for regional things you can omit zone)

2) **Install Local Tooling (versions pinned for reproducibility)**
- `gcloud` (>= 468.x), `kubectl` (>= 1.30), `helm` (>= 3.15), `terraform` (>= 1.8), `git` (>= 2.40).
- Verify with `--version` and note them in the repo README.

3) **Create Repos**
- On GitHub, create two repositories: `infra-gke` (infra) and `gitops-gke` (GitOps). Both can be private.
- Protect `main` branch (require PR + status checks; we’ll wire CI in Phase 5).

4) **Set Up Access for Argo CD to GitHub (decide one)**
- **Deploy Key (recommended for a single repo):**
  - Generate an SSH keypair dedicated to `gitops-gke` (no passphrase): `ssh-keygen -t ed25519 -C "argocd-deploy" -f ./argocd-deploy`
  - Add the **public** key as a **Deploy Key** (read‑only) to `gitops-gke`.
  - Keep the **private** key safe; it will be stored as a Secret in Argo CD later.
- **OR Personal Access Token (PAT):** create a fine‑scoped token with **read‑only repo** access. Save it securely for Phase 2/3.

5) **Scaffold the `gitops-gke` Repository**
Create the following structure and seed files:

```
/gitops-gke
├─ clusters/
│  └─ gke-autopilot/
│     ├─ README.md
│     ├─ project/               # Argo CD Project definitions
│     ├─ root/                  # Root Application (App-of-Apps)
│     └─ apps/                  # Child Application manifests
├─ envs/
│  ├─ dev/
│  │  ├─ namespace.yaml
│  │  ├─ policies/              # (ResourceQuota/LimitRange - optional in Phase 1)
│  │  └─ values/                # env-specific values for Helm apps
│  └─ prod/
│     ├─ namespace.yaml
│     ├─ policies/
│     └─ values/
└─ apps/
   ├─ app-a/                    # in-house Helm chart
   │  ├─ Chart.yaml
   │  ├─ templates/
   │  └─ values.yaml            # base values, env overlays live in envs/*/values
   └─ app-b/                    # third-party chart reference (no code here)
      └─ README.md
```

Seed minimal contents:
- Top‑level `README.md` describing the repo purpose and App‑of‑Apps.
- `.gitignore` including `*.key`, `.env*`, and tool caches.
- `envs/*/namespace.yaml` with a simple Namespace manifest for `dev` and `prod`.
- `apps/app-a/Chart.yaml` (name `app-a`, version `0.1.0`) and an empty `templates/.keep` file to start.
- `apps/app-b/README.md` explaining which vendor chart you will pin (decide nginx or redis in Phase 4).

6) **Scaffold the `infra-gke` Repository**
Add a minimal structure (Terraform will be filled in Phase 1):

```
/infra-gke
├─ README.md
├─ .gitignore
├─ env/                         # optional: tfvars per env if you want
│  ├─ dev.tfvars
│  └─ prod.tfvars
└─ terraform/
   ├─ modules/                  # (cluster, network) to be added later
   ├─ main.tf
   ├─ providers.tf
   ├─ variables.tf
   └─ outputs.tf
```

Populate placeholders in the Terraform files (comments only) so `terraform init` won’t fail later. Document that state can be local for the lab (remote backend optional).

7) **Decide the Two Apps (record your choice)**
- **App A:** simple web service (e.g., a tiny `nginx` container served via a Service) delivered as an in‑house Helm chart.
- **App B:** a common third‑party chart (e.g., `bitnami/redis` or `ingress‑nginx`) that is compatible with Autopilot constraints. Record chart repo URL and target version in `apps/app-b/README.md`.

8) **Documentation & Conventions**
- Add CONTRIBUTING.md with workflow: PRs to `main`, CI checks, Argo CD is the deployer.
- Add `.editorconfig` and commit message convention (e.g., Conventional Commits) to keep history clean.

---

### Phase 0 — Verification Checklist (Definition of Ready)

- [ ] **GCP project** exists, billing enabled, and you can run `gcloud projects describe $GCP_PROJECT_ID` successfully.
- [ ] **IAM roles**: you (or the CI user) have the listed roles or `Owner` for bootstrap.
- [ ] **Tooling versions** match or exceed the pinned versions (`gcloud`, `kubectl`, `helm`, `terraform`, `git`).
- [ ] **Two GitHub repos** created: `infra-gke` and `gitops-gke`; `main` is protected.
- [ ] **Access method decided** for Argo CD → GitHub (Deploy Key or PAT) and the credential is generated and stored securely.
- [ ] **gitops-gke** repo contains the scaffolded folder structure and seed files; push to GitHub succeeds.
- [ ] **infra-gke** repo contains Terraform skeleton files; `terraform -chdir=terraform init` runs without error (with placeholder providers).
- [ ] **Namespaces manifests** exist for `dev` and `prod` in `gitops-gke/envs/*/namespace.yaml`.
- [ ] **App selections** documented for App A & App B, including chart repo and target version (for App B).
- [ ] **Docs** present: README(s), CONTRIBUTING, `.editorconfig`, and `.gitignore`.

> When every item is checked, proceed to **Phase 1 — Provision Infra with Terraform**.
