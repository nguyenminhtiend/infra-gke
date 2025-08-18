# GKE Application Infrastructure

Complete infrastructure and application deployment on Google Kubernetes Engine (GKE) using modern DevOps practices.

## Project Status

### ✅ Phase 1: Foundation & Local Setup (COMPLETED)

- **GCP Project Setup**: APIs enabled, service accounts created
- **Local Development Environment**: All tools installed (gcloud, terraform, kubectl, kubectx, k9s, helm, etc.)
- **Terraform Structure**: Base modules and environments configured
- **GitHub Repository Setup**: Workflow files and CODEOWNERS configured

### 🚧 Current Infrastructure

- **Project ID**: `rich-principle-469207-v0`
- **Region**: `asia-southeast1` (Singapore)
- **Terraform State**: Stored in GCS bucket `rich-principle-469207-v0-terraform-state`

## Project Structure

```
infra-gke/
├── terraform/
│   ├── environments/
│   │   ├── dev/           # Development environment
│   │   ├── staging/       # Staging environment (pending)
│   │   └── prod/          # Production environment (pending)
│   └── modules/
│       ├── gke-autopilot/ # GKE cluster module (pending)
│       ├── networking/    # VPC and networking (pending)
│       ├── iam/          # IAM and security (pending)
│       ├── observability/ # Monitoring stack (pending)
│       └── security/     # Security policies (pending)
├── apps/                 # NestJS microservices (pending)
├── argocd/              # GitOps applications (pending)
├── .github/workflows/   # CI/CD pipelines
└── scripts/            # Setup scripts
```

## Quick Start

### Prerequisites

- macOS with Homebrew
- GCP account with billing enabled
- Docker Desktop

### Local Development

```bash
# Navigate to project
cd /Users/messi/Projects/Others/infra-gke

# Check Terraform setup
cd terraform/environments/dev
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/terraform-gcp-key.json"
terraform init
terraform validate

# Return to project root
cd ../../..
```

### Next Steps

1. **Phase 2**: Core Infrastructure (GKE cluster, networking, security)
2. **Phase 3**: Application Setup (NestJS microservices)
3. **Phase 4**: CI/CD Pipeline (GitHub Actions, ArgoCD)
4. **Phase 5**: Load Balancing & Networking
5. **Phase 6**: Observability Stack

## Available Commands

```bash
# Terraform commands (from terraform/environments/dev/)
terraform plan          # Preview infrastructure changes
terraform apply         # Apply infrastructure changes
terraform destroy       # Destroy infrastructure

# Kubernetes commands (once cluster is created)
kubectl get nodes       # List cluster nodes
kubectl get pods        # List running pods
k9s                    # Terminal UI for Kubernetes

# Development tools
kubectx                # Switch between clusters
stern app-name         # Multi-pod log streaming
argocd login           # Login to ArgoCD
```

## Security Notes

- Service account keys are stored locally in `terraform/environments/dev/terraform-gcp-key.json`
- All sensitive files are excluded by `.gitignore`
- Workload Identity will be configured for production deployments

## Support

For detailed setup instructions, see:
- `local-setup-guide.md` - Complete local environment setup
- `monorepo-setup-guide.md` - NestJS application structure
- `gke-deployment-plan.md` - Full deployment plan
