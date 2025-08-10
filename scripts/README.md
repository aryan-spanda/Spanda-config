# Spanda Platform - Automation Scripts

This directory contains automation scripts for managing the Spanda Platform GitOps configuration.

## � **NEW: Direct API Application Generator v3.0**

**Breaking Change:** The platform now supports **direct GitHub API access** for reading application configurations, eliminating the need for local repository cloning!

### **⚡ Quick Start (Recommended)**
```bash
# Single command - reads directly from GitHub API
cd config-repo/scripts/
./generate-argocd-applications-simple.sh --apply
```

**Benefits:**
- 🚀 **10x Faster** - 5-10 seconds vs 30-60 seconds
- 💾 **Zero Disk Usage** - No local repository clones needed  
- 🔄 **Always Current** - Reads directly from source repositories
- 🧹 **No Maintenance** - No repository synchronization required

## 📁 Scripts

### `generate-argocd-applications-simple.sh` ⭐ **RECOMMENDED**

**NEW v3.0:** Direct GitHub API application generator - no cloning required!

**Features:**
- ✅ **Direct GitHub API access** - reads `platform-requirements.yml` from repositories
- ✅ **Remote validation** - validates Helm chart structure without cloning
- ✅ **Multi-environment support** - generates dev, staging, production variants
- ✅ **ArgoCD Image Updater** - automatic Docker image update configuration
- ✅ **Conservative polling** - 5-minute intervals to avoid rate limits
- ✅ **Auto-deployment** - optional `--apply` flag for immediate deployment

**Usage:**
```bash
# Generate ArgoCD manifests only
./generate-argocd-applications-simple.sh

# Generate and deploy immediately  
./generate-argocd-applications-simple.sh --apply

# Show help
./generate-argocd-applications-simple.sh --help
```

**Prerequisites:**
- `yq` - YAML processor
- `curl` - HTTP client  
- `jq` - JSON processor
- `application-sources.txt` - List of repository URLs

**Configuration (application-sources.txt):**
```plaintext
# List of application repositories
https://github.com/aryan-spanda/Test-Application/tree/testing
https://github.com/your-org/frontend-app.git
https://github.com/your-org/backend-api/tree/develop
```

**Generated Structure:**
```
config-repo/applications/
├── test-application/
│   ├── README.md
│   └── argocd/
│       ├── app-dev.yaml
│       ├── app-staging.yaml
│       └── app-prod.yaml
└── vllm-service/
    ├── README.md
    └── argocd/
        ├── app-dev.yaml
        └── app-prod.yaml
```

## 🔄 Workflow

1. **Developer** adds `platform-requirements.yml` to their app repository
2. **Platform Team** runs the generation script
3. **ArgoCD Applications** are created automatically
4. **Deploy** to cluster: `kubectl apply -f applications/*/argocd/`

## 🎯 Benefits

- ✅ **No Helm charts in config repo** - Clean GitOps separation
- ✅ **Automatic discovery** - Scans repositories for platform requirements
- ✅ **Consistent structure** - All applications follow the same pattern
- ✅ **Environment-specific** - Proper namespace and sync policy per environment
- ✅ **Documentation** - Auto-generated README for each application

## 🛠️ Installation

### Install yq (YAML processor)

**Windows (PowerShell):**
```powershell
Invoke-WebRequest -Uri https://github.com/mikefarah/yq/releases/latest/download/yq_windows_amd64.exe -OutFile yq.exe
# Add yq.exe to your PATH
```

**Linux:**
```bash
curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o yq && chmod +x yq
sudo mv yq /usr/local/bin/
```

**macOS:**
```bash
brew install yq
```

## 💡 Adding New Applications

1. Create `platform-requirements.yml` in your app repository:
   ```yaml
   app:
     name: "my-new-app"
     repoURL: "https://github.com/aryan-spanda/my-new-app.git"
     chartPath: "deploy/helm"
   
   environments:
     - dev
     - staging
     - production
   
   platform:
     modules:
       vpc_networking: true
       # ... other platform requirements
   ```

2. Run the generation script:
   ```bash
   ./scripts/generate-argocd-applications.sh https://github.com/aryan-spanda/my-new-app.git
   ```

3. Apply to cluster:
   ```bash
   kubectl apply -f applications/my-new-app/argocd/
   ```

That's it! Your application is now managed by ArgoCD with proper GitOps practices. 🎉
