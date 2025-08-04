# Platform Team Onboarding Workflow

This document describes the step-by-step process for the platform team to onboard new applications using the automated ArgoCD generation system.

## Overview

The platform team manages application onboarding through a centralized workflow that:
1. Maintains a master list of application repositories
2. Syncs local copies of application repositories  
3. Generates ArgoCD application manifests automatically
4. Keeps everything under version control (except local clones)

## Directory Structure

```
config-repo/
├── application-sources.txt          # Master list of app repositories
├── local-app-repos/                 # Local clones (gitignored)
│   └── Test-Application/            # Cloned app repos
├── applications/                    # Generated ArgoCD manifests
│   └── test-application/
│       ├── README.md
│       └── argocd/
│           ├── app-dev.yaml
│           ├── app-staging.yaml
│           └── app-production.yaml
└── scripts/
    ├── sync-app-repos.sh           # Sync/clone repositories
    └── generate-argocd-applications.sh  # Generate ArgoCD manifests
```

## Platform Team Workflow

### 1. Add New Application to Master List

When a development team requests onboarding, add their repository URL to `application-sources.txt`:

```bash
cd config-repo
echo "https://github.com/your-org/new-app.git" >> application-sources.txt
```

**Note:** You can specify a specific branch using the GitHub tree URL format:
```bash
echo "https://github.com/your-org/new-app/tree/feature-branch" >> application-sources.txt
```

### 2. Sync Application Repositories

Pull the latest changes from all application repositories:

```bash
cd config-repo
./scripts/sync-app-repos.sh
```

This will:
- Clone new repositories to `local-app-repos/`
- Pull latest changes for existing repositories
- Handle branch switching if specified

### 3. Generate ArgoCD Applications

Generate ArgoCD application manifests for all applications:

```bash
cd config-repo
./scripts/generate-argocd-applications.sh
```

Or generate for a specific application:

```bash
./scripts/generate-argocd-applications.sh ./local-app-repos/new-app
```

### 4. Review and Commit Changes

Review the generated ArgoCD applications:

```bash
git status
git diff applications/
```

Commit the new configuration:

```bash
git add applications/new-app/
git commit -m "feat(onboard): Add ArgoCD manifests for new-app"
git push origin main
```

## Application Requirements

For successful onboarding, application repositories must have:

1. **platform-requirements.yml** in the root directory:
```yaml
app:
  name: "my-application"
  repoURL: "https://github.com/your-org/my-application.git"
  chartPath: "deploy/helm"

environments:
  - dev
  - staging
  - production
```

2. **Helm Charts** at the specified `chartPath` with:
   - `Chart.yaml`
   - `values.yaml` (default values)
   - `values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`
   - `templates/` directory with Kubernetes manifests

## Key Benefits

- **Centralized Control**: Platform team maintains full control over deployments
- **Consistency**: All applications follow the same deployment patterns
- **Automation**: Reduces manual work and errors
- **Version Control**: All configuration changes are tracked
- **Branch Support**: Can work with specific branches for testing
- **Local Development**: Local clones enable offline work and faster iteration

## Troubleshooting

### Repository Clone Issues
```bash
# Clean and re-sync a specific repository
rm -rf local-app-repos/problematic-app
./scripts/sync-app-repos.sh
```

### Missing platform-requirements.yml
```bash
# Check what files exist in the app repository
ls -la local-app-repos/app-name/
```

### Generation Errors
```bash
# Test generation for a specific app
./scripts/generate-argocd-applications.sh ./local-app-repos/app-name
```

## Security Notes

- `local-app-repos/` is gitignored and contains sensitive repository data
- Never commit the `local-app-repos/` directory to version control
- Application secrets should be managed through the platform's secret management system
- Repository access tokens should be managed securely
