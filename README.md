# Spanda AI Platform - Configuration Repository

This repository contains all deployment configurations for the Spanda AI Platform applications using GitOps principles. It serves as the **single source of truth** for what's deployed in your Kubernetes clusters.

## 🎯 Repository Purpose

This config repository follows the GitOps pattern where:
- **Source code** lives in application repositories (e.g., Test-Application)
- **Deployment configurations** live here in the config repository
- **ArgoCD** monitors this repository and automatically deploys changes to Kubernetes

## 📁 Repository Structure

```
config-repo/
├── 🚀 landing-zone/                   # ArgoCD Application definitions
│   └── applications/
│       ├── test-application-prod.yaml      # Production ArgoCD app
│       ├── test-application-staging.yaml   # Staging ArgoCD app
│       └── README.md
│
├── 📱 apps/                          # Application-specific configurations
│   └── test-application/
│       ├── Chart.yaml                # Helm chart metadata
│       ├── values-prod.yaml          # Production values
│       ├── values-staging.yaml       # Staging values
│       └── templates/                # Kubernetes templates
│           ├── _helpers.tpl
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── serviceaccount.yaml
│           ├── configmap.yaml
│           └── hpa.yaml
│
├── 🏗️ infrastructure/               # Infrastructure as Code (Future)
│   ├── namespaces/
│   ├── rbac/
│   └── monitoring/
│
└── 📚 docs/                         # Documentation
    └── README.md
```

## 🔄 GitOps Flow

### How Automatic Deployments Work

1. **Code Push**: Developer pushes code to Test-Application repository
2. **CI/CD Pipeline**: GitHub Actions runs tests and builds Docker image
3. **Image Push**: New image pushed to GitHub Container Registry (GHCR)
4. **Config Update**: GitHub Actions automatically updates image tags in this repository
5. **ArgoCD Sync**: ArgoCD detects changes and deploys to Kubernetes cluster

## 🌍 Environment Configuration

### Production (`values-prod.yaml`)
- **Replicas**: 3 pods for high availability
- **Resources**: 1 CPU, 1Gi memory limits
- **Autoscaling**: 3-10 replicas based on CPU/memory
- **Ingress**: TLS enabled with Let's Encrypt
- **Security**: Read-only filesystem, non-root user

### Staging (`values-staging.yaml`)
- **Replicas**: 1 pod for cost efficiency
- **Resources**: 500m CPU, 512Mi memory limits
- **Autoscaling**: Disabled
- **Ingress**: HTTP only for testing
- **Security**: Same security context as production
├── scripts/                          # Helper scripts
│   ├── update-image.sh              # Update Docker image tags
│   └── validate-kustomize.sh        # Validate Kustomization files
│
└── README.md
```

## GitOps Workflow

### 1. **Application Source Code** (Separate Repository)
```
https://github.com/aryan-spanda/Test-Application.git
├── frontend/           # React source code
└── backend/            # Node.js source code
```

### 2. **Configuration Repository** (This Repository)
```
https://github.com/your-org/spandaai-config.git
├── apps/               # All Kubernetes manifests
└── cluster-config/     # Cluster-wide config
```

### 3. **Deployment Process**
1. **Developer** pushes code changes to application repository
2. **CI/CD Pipeline** builds Docker images and pushes to registry
3. **Image Updater** (or manual process) updates image tags in this repository
4. **ArgoCD** detects changes and automatically deploys to Kubernetes

## Environment Management

### Base Configuration
- **Location**: `apps/<app-name>/base/`
- **Purpose**: Common configuration shared across all environments
- **Contains**: Deployment, Service, Ingress, ConfigMap, Secrets

### Environment Overlays
- **Production**: `apps/<app-name>/overlays/production/`
  - Higher replica counts
  - Production domain names
  - Resource limits optimized for production
  - Production-specific environment variables

- **Staging**: `apps/<app-name>/overlays/staging/`
  - Lower replica counts
  - Staging domain names
  - Development-friendly settings

## Updating Applications

### Method 1: Manual Update (Quick)
```bash
# Update image tag for production deployment
cd apps/spandaai-frontend/overlays/production
# Edit kustomization.yaml and change newTag value
# Commit and push changes
```

### Method 2: Using Helper Script
```bash
# Use the provided script
./scripts/update-image.sh spandaai-frontend production v1.2.3
git add .
git commit -m "Deploy spandaai-frontend v1.2.3 to production"
git push
```

### Method 3: ArgoCD Image Updater (Automated)
ArgoCD Image Updater can automatically detect new image tags and update this repository.

## Adding New Applications

1. **Create directory structure**:
   ```bash
   mkdir -p apps/new-app/{base,overlays/{production,staging}}
   ```

2. **Create base manifests**:
   - `deployment.yaml`
   - `service.yaml`
   - `ingress.yaml` (if needed)
   - `configmap.yaml` (if needed)
   - `kustomization.yaml`

3. **Create environment overlays** with appropriate overrides

4. **Register with ArgoCD** by adding to `cluster-config/argocd/applications.yaml`

## Security

### Secrets Management
- **Development**: Use regular Kubernetes Secrets (base64 encoded)
- **Production**: Use Sealed Secrets for encrypted storage in Git
- **Alternative**: External Secrets Operator with external secret stores

### Creating Sealed Secrets
```bash
# Install kubeseal CLI tool first
echo -n "your-secret-value" | kubeseal --raw --from-file=/dev/stdin --name=secret-name --namespace=namespace-name
```

## Validation

### Validate Kustomization Files
```bash
# Validate all configurations
./scripts/validate-kustomize.sh

# Validate specific application
kustomize build apps/spandaai-frontend/overlays/production
```

### Preview Changes
```bash
# See what would be applied
kubectl apply --dry-run=client -k apps/spandaai-frontend/overlays/production
```

## CI/CD Integration

This repository should have CI/CD pipelines that:

1. **Validate**: Run `kustomize build` on all applications
2. **Security Scan**: Check for security issues in manifests
3. **Policy Enforcement**: Use OPA/Gatekeeper for policy validation
4. **Deployment**: Allow ArgoCD to sync changes automatically

## Monitoring

Applications are configured to be scraped by Prometheus:
- **Frontend**: Exposes metrics on `/metrics` endpoint
- **Backend**: Exposes metrics on `/api/metrics` endpoint
- **Monitoring**: Configured in `cluster-config/monitoring/`

## Troubleshooting

### Common Issues

1. **Application not syncing**:
   ```bash
   # Check ArgoCD application status
   kubectl get applications -n argocd
   ```

2. **Kustomization errors**:
   ```bash
   # Validate specific overlay
   kustomize build apps/spandaai-frontend/overlays/production
   ```

3. **Image pull errors**:
   - Check image registry credentials
   - Verify image tag exists in registry
   - Check namespace has proper pull secrets

### Useful Commands

```bash
# Check all ArgoCD applications
kubectl get applications -n argocd

# Force sync an application
argocd app sync spandaai-frontend-prod

# Check application logs
kubectl logs -n spandaai-frontend deployment/spandaai-frontend

# View current image tags
kubectl get deployment -n spandaai-frontend spandaai-frontend -o yaml | grep image:
```

## Contributing

1. **Create feature branch**: `git checkout -b feature/new-app`
2. **Make changes**: Add/modify manifests following existing patterns
3. **Validate**: Run `./scripts/validate-kustomize.sh`
4. **Create PR**: Submit for review
5. **Merge**: Changes automatically deployed by ArgoCD

## Links

- **Application Repository**: https://github.com/aryan-spanda/Test-Application.git
- **Platform Repository**: https://github.com/your-org/spandaai-platform-deployment.git
- **ArgoCD Dashboard**: https://argocd.your-cluster.com
- **Monitoring**: https://grafana.your-cluster.com
