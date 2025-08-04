# test-application - ArgoCD Applications

This directory contains ArgoCD application definitions for `test-application`.

## 📁 Structure
```
applications/test-application/
├── README.md           # This file
└── argocd/            # ArgoCD application manifests
    ├── app-dev.yaml
    ├── app-production.yaml
    ├── app-staging.yaml
```

## 🚀 Deployment

### Apply ArgoCD Applications
```bash
# Apply all environments
kubectl apply -f applications/test-application/argocd/

# Apply specific environment
kubectl apply -f applications/test-application/argocd/app-dev.yaml
```

### Sync Applications
```bash
# Sync all environments
argocd app sync test-application-dev
argocd app sync test-application-staging
argocd app sync test-application-production

# Sync specific environment
argocd app sync test-application-dev
```

## 📋 Application Details

- **Repository**: https://github.com/aryan-spanda/Test-Application.git
- **Chart Path**: deploy/helm
- **Environments**: dev staging production 

## 🔄 Auto-Generated

These files were automatically generated from `platform-requirements.yml`.
To update, run the sync and generation process:

```bash
cd config-repo
./scripts/sync-app-repos.sh
./scripts/generate-argocd-applications.sh ./local-app-repos/test-application
```
