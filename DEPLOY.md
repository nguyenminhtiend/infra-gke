# Deployment Guide

## Phase 2: Core Infrastructure Ready ✅

The core infrastructure is ready to deploy. This will create:

### Infrastructure Components

- **VPC Network**: Custom VPC with private subnets
- **GKE Autopilot Cluster**: Fully managed Kubernetes cluster
- **Artifact Registry**: Docker repository for container images
- **IAM & Security**: Service accounts with Workload Identity
- **Networking**: Cloud NAT, firewall rules, load balancer IP

### Deploy Infrastructure

```bash
# Navigate to dev environment
cd terraform/environments/dev

# Set credentials (if not already set)
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/terraform-gcp-key.json"

# Deploy infrastructure (takes ~10-15 minutes)
terraform apply

# Configure kubectl access
gcloud container clusters get-credentials gke-autopilot-dev \
  --region asia-southeast1 \
  --project rich-principle-469207-v0
```

### Verify Deployment

```bash
# Check cluster status
kubectl get nodes
kubectl get namespaces

# Check Artifact Registry
gcloud artifacts repositories list --location=asia-southeast1

# View static IP for load balancer
terraform output static_ip_address
```

### Estimated Costs (Monthly)

- **GKE Autopilot**: ~$25-50 (based on workload)
- **VPC & Networking**: ~$5-10
- **Artifact Registry**: ~$1-5
- **Total**: ~$30-65/month for dev environment

### Next Steps After Deployment

1. **Phase 3**: Application Setup (NestJS services)
2. **Phase 4**: CI/CD Pipeline (GitHub Actions + ArgoCD)
3. **Phase 5**: Load Balancing & Ingress
4. **Phase 6**: Observability Stack

### Cleanup

```bash
# Destroy all infrastructure when done
terraform destroy
```

⚠️ **Note**: GKE Autopilot clusters take ~10-15 minutes to create and ~10 minutes to destroy.
