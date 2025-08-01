# 🚀 Config Repository Restructuring Guide

## What Changed

The config repository has been restructured to follow GitOps best practices with clean separation of concerns.

### ✅ New Structure (GitOps Compliant)

```
config-repo/
├── applications/                    # ArgoCD Application definitions
│   └── test-application/
│       └── argocd/
│           ├── app-dev.yaml        # Development environment
│           ├── app-staging.yaml    # Staging environment
│           └── app-prod.yaml       # Production environment
├── infrastructure/                  # Cluster-wide infrastructure
│   └── namespaces/
│       └── app-namespaces.yaml
├── argocd/                         # ArgoCD configuration
│   └── projects/
│       └── spanda-applications.yaml
├── cluster-config/                 # Existing cluster config (preserved)
│   └── argocd/
│       └── app-of-apps.yaml       # Updated to point to new structure
└── scripts/                        # Preserved onboarding scripts
```

### 🔄 Key Changes Made

1. **ArgoCD Applications Now Point to App Repository**
   - Source: `https://github.com/aryan-spanda/spanda-test-app.git`
   - Path: `charts/test-application`
   - Uses app repo's values files

2. **Preserved Image Updater Functionality**
   - Dev: Updates on any `latest` or `dev-*` tags
   - Staging: Updates on `latest`, `main-*`, or commit SHAs
   - Prod: Only updates on semantic version tags (`v1.2.3`)

3. **Enhanced Security**
   - Production requires manual sync (no auto-sync)
   - Proper ArgoCD project with RBAC
   - Environment-specific namespaces

## 🏗️ Application Repository Setup

**Create `spanda-test-app` repository with this structure:**

```
spanda-test-app/
├── src/                           # Your Node.js source code
├── charts/                        # MOVE HELM CHART HERE
│   └── test-application/
│       ├── Chart.yaml
│       ├── values.yaml           # Base values (environment agnostic)
│       ├── values-dev.yaml       # Development overrides  
│       ├── values-staging.yaml   # Staging overrides
│       ├── values-prod.yaml      # Production overrides
│       └── templates/            # MOVE FROM config-repo/apps/test-application/templates/
├── .github/workflows/            # CI/CD pipeline
└── Dockerfile
```

## 🔧 Migration Steps

### Step 1: Create Application Repository
```bash
# Create new repository: spanda-test-app
mkdir spanda-test-app && cd spanda-test-app

# Copy source code (from your existing app)
cp -r /path/to/Test-Application/src ./
cp /path/to/Test-Application/Dockerfile ./
cp /path/to/Test-Application/package.json ./

# Create charts directory
mkdir -p charts/test-application
```

### Step 2: Move Helm Chart to App Repository
```bash
# Copy Helm chart from config-repo to app-repo
cp -r config-repo/apps/test-application/* spanda-test-app/charts/test-application/

# Update values files to be environment-agnostic (see examples)
```

### Step 3: Deploy Updated ArgoCD Applications
```bash
# Apply the new ArgoCD applications
kubectl apply -f config-repo/applications/test-application/argocd/
kubectl apply -f config-repo/argocd/projects/
kubectl apply -f config-repo/infrastructure/namespaces/
```

### Step 4: Clean Up Old Structure (After Verification)
```bash
# Once confirmed working, remove old structure
rm -rf config-repo/apps/
rm -rf config-repo/landing-zone/
```

## 🎯 Benefits

✅ **GitOps Compliance**: App owns its chart, config owns deployments
✅ **Preserved Functionality**: All Image Updater features retained
✅ **Better Security**: Production manual sync, proper RBAC
✅ **Scalability**: Easy to add new applications
✅ **Clean Separation**: Clear boundaries between app and infra teams

## ⚠️ Important Notes

1. **Backward Compatibility**: Legacy namespaces preserved for smooth transition
2. **Image Updater**: All existing automation preserved and enhanced
3. **Onboarding Scripts**: Existing scripts preserved in `/scripts/`
4. **App-of-Apps**: Updated to point to new structure

## 🔄 What's Preserved

- ✅ ArgoCD Image Updater functionality
- ✅ App-of-Apps bootstrap pattern  
- ✅ Onboarding automation scripts
- ✅ Environment-specific configurations
- ✅ Sync waves and annotations
- ✅ All existing labels and metadata
