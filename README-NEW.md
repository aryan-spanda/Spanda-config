# Spanda Platform - Configuration Repository

This repository contains all deployment configurations for the Spanda Platform using GitOps principles with ArgoCD. It serves as the **single source of truth** for what's deployed in your Kubernetes clusters.

## 🎯 Repository Purpose

This config repository follows the GitOps pattern where:
- **Application source code and Helm charts** live in application repositories (e.g., Test-Application)
- **Deployment configurations (ArgoCD Applications)** live here in the config repository
- **ArgoCD** monitors this repository and automatically deploys changes to Kubernetes
- **ArgoCD Image Updater** automatically updates image tags for continuous deployment

## 📁 Repository Structure

```
config-repo/
├── 🚀 applications/                   # ArgoCD Application definitions
│   └── test-application/
│       ├── README.md                  # Application-specific documentation
│       └── argocd/
│           ├── app-dev.yaml          # Development environment
│           ├── app-staging.yaml      # Staging environment
│           └── app-production.yaml   # Production environment
│
├── 🏗️ infrastructure/                # Cluster-wide infrastructure
│   └── namespaces/
│       └── app-namespaces.yaml       # Environment namespaces (dev, staging, production)
│
├── ⚙️ argocd/                        # ArgoCD configuration
│   └── projects/
│       └── spanda-applications.yaml  # ArgoCD project with RBAC
│
├── 🔄 cluster-config/                # Bootstrap configuration
│   └── argocd/
│       └── app-of-apps.yaml         # App-of-Apps pattern for ArgoCD
│
├── 🛠️ scripts/                      # Platform automation scripts
│   ├── main.sh                      # Main orchestration script
│   ├── sync-app-repos.sh           # Repository synchronization
│   ├── generate-argocd-applications.sh # ArgoCD manifest generation
│   └── README-MAIN.md               # Script usage documentation
│
├── 📋 local-app-repos/               # Local repository clones (gitignored)
│   └── Test-Application/            # Synced application repositories
│
├── application-sources.txt           # Master list of application repositories
└── .gitignore                       # Excludes local clones and temp files
```

## 🚀 Platform Team Workflow

The platform team uses an automated workflow to onboard and manage applications:

### 1️⃣ Add New Application
```bash
cd config-repo
echo "https://github.com/your-org/new-app.git" >> application-sources.txt
# Or specify a branch: echo "https://github.com/your-org/new-app/tree/testing" >> application-sources.txt
```

### 2️⃣ Run Main Orchestration Script
```bash
# Process all applications
./scripts/main.sh

# Or process specific application
./scripts/main.sh MyApplication
```

**The main script automatically:**
- ✅ Syncs all application repositories
- ✅ Generates ArgoCD application manifests
- ✅ Commits changes to testing branch
- ✅ Pushes to remote repository
- ✅ Provides GitHub links for review

### 3️⃣ Review and Merge
- Review changes in testing branch
- Create pull request to main branch
- Once merged, ArgoCD detects and deploys applications

## 🔄 GitOps Flow & Continuous Deployment

### How Automatic Deployments Work

1. **Code Push**: Developer pushes code to application repository (e.g., Test-Application)
2. **CI/CD Pipeline**: GitHub Actions builds and pushes Docker image to GHCR
3. **Image Update**: ArgoCD Image Updater automatically updates Helm values
4. **Deployment**: ArgoCD syncs changes to Kubernetes clusters

### ArgoCD Image Updater Configuration

All environments are configured with automatic image updates:

```yaml
# Applied to all environments (dev, staging, production)
argocd-image-updater.argoproj.io/image-list: app-name=ghcr.io/aryan-spanda/app-name
argocd-image-updater.argoproj.io/app-name.update-strategy: semver
argocd-image-updater.argoproj.io/app-name.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
argocd-image-updater.argoproj.io/write-back-method: git
```

## 🌍 Environment Configuration

### 🟢 Development (`app-dev.yaml`)
- **Namespace**: `development`
- **Sync Policy**: Automated (selfHeal: true, prune: true)
- **Image Updates**: Automatic with semver tags
- **Purpose**: Rapid development and testing

### 🟡 Staging (`app-staging.yaml`)
- **Namespace**: `staging`
- **Sync Policy**: Automated (selfHeal: true, prune: true)
- **Image Updates**: Automatic with semver tags
- **Purpose**: Pre-production testing and validation

### 🔴 Production (`app-production.yaml`)
- **Namespace**: `production`
- **Sync Policy**: Manual (no automated sync for safety)
- **Image Updates**: Automatic with semver tags
- **Revision History**: Limited to 10 for performance
- **Purpose**: Live production workloads

## 📋 Application Requirements

For successful onboarding, application repositories must have:

### 1. `platform-requirements.yml` in the root directory:
```yaml
app:
  name: "my-application"
  repoURL: "https://github.com/your-org/my-application.git"
  chartPath: "deploy/helm"
  type: "fullstack"        # fullstack, frontend, backend, api
  team: "development-team" # Team responsible for the application

environments:
  - dev
  - staging
  - production
```

### 2. Helm Charts at the specified `chartPath`:
```
deploy/helm/
├── Chart.yaml
├── values.yaml              # Base values
├── values-dev.yaml          # Development overrides
├── values-staging.yaml      # Staging overrides
├── values-production.yaml   # Production overrides
└── templates/               # Kubernetes manifests
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── ...
```

## 🛠️ Script Details

### Main Orchestration Script (`scripts/main.sh`)
The primary automation tool that handles the complete onboarding workflow:

```bash
# Usage
./scripts/main.sh                    # Process all applications
./scripts/main.sh MyApplication      # Process specific application
```

**What it does:**
1. 🔄 Syncs application repositories
2. ⚙️ Generates ArgoCD application manifests
3. 📋 Detects changes and creates smart commit messages
4. 🌿 Switches to testing branch
5. 💾 Commits changes with descriptive messages
6. 🚀 Pushes to remote repository

### Repository Sync Script (`scripts/sync-app-repos.sh`)
Manages local copies of all application repositories:

- Clones new repositories from `application-sources.txt`
- Updates existing repositories with latest changes
- Supports branch-specific cloning (e.g., `/tree/testing`)
- Stores clones in `local-app-repos/` (gitignored)

### ArgoCD Generator Script (`scripts/generate-argocd-applications.sh`)
Creates production-grade ArgoCD application manifests:

- Reads `platform-requirements.yml` from application repositories
- Generates environment-specific ArgoCD applications
- Includes ArgoCD Image Updater configuration
- Creates comprehensive metadata and labels
- Supports both single application and bulk processing

## 🔒 Security & Best Practices

### Production Safety
- **Manual Sync**: Production environments require manual approval
- **Semantic Versioning**: Only allows proper version tags (v1.2.3)
- **Git Audit Trail**: All changes tracked via git writeback
- **RBAC**: ArgoCD projects provide security boundaries

### Secrets Management
- Application secrets managed in application repositories
- Platform secrets managed through external secret stores
- No secrets stored in this configuration repository

### Access Control
- Platform team controls deployment configurations
- Application teams control source code and Helm charts
- Clear separation of responsibilities

## 📊 Monitoring & Observability

### ArgoCD Dashboard
- View application sync status
- Monitor deployment health
- Track sync history and errors

### Application Health
Applications are configured with:
- **Liveness probes**: `/health` endpoint
- **Readiness probes**: Application-specific health checks
- **Metrics**: Prometheus integration for monitoring

## 🆘 Troubleshooting

### Common Issues

#### Repository Clone Failures
```bash
# Clean and re-sync specific repository
rm -rf local-app-repos/problematic-app
./scripts/sync-app-repos.sh
```

#### Missing platform-requirements.yml
```bash
# Check application repository structure
ls -la local-app-repos/app-name/
```

#### ArgoCD Sync Issues
```bash
# Check application status
kubectl get applications -n argocd
kubectl describe application app-name-dev -n argocd
```

#### Image Update Issues
```bash
# Check ArgoCD Image Updater logs
kubectl logs -n argocd deployment/argocd-image-updater
```

### Getting Help

1. **Check application README**: Each app has specific documentation
2. **Review ArgoCD logs**: Application sync and health status
3. **Validate Helm charts**: Use `helm template` to test locally
4. **Platform team**: Contact for configuration repository issues

## 🎉 Key Benefits

### For Platform Team
- ✅ **Centralized Control**: Single source of truth for deployments
- ✅ **Automation**: Reduced manual work and human errors
- ✅ **Consistency**: All applications follow same patterns
- ✅ **Security**: Production safety with manual approvals
- ✅ **Scalability**: Easy to onboard new applications

### For Development Teams
- ✅ **Autonomy**: Full control over source code and Helm charts
- ✅ **Visibility**: Clear deployment status and history
- ✅ **Speed**: Automated image updates for faster releases
- ✅ **Safety**: Production controls prevent accidental deployments

### For Operations
- ✅ **GitOps**: Declarative, version-controlled infrastructure
- ✅ **Observability**: Rich metadata and monitoring integration
- ✅ **Disaster Recovery**: Git history enables quick rollbacks
- ✅ **Compliance**: Audit trail of all changes

---

## 🚀 Quick Start

1. **Add your application** to `application-sources.txt`
2. **Run the main script**: `./scripts/main.sh`
3. **Review changes** in the testing branch
4. **Merge to main** to deploy via ArgoCD

The platform handles the rest automatically! 🎉
