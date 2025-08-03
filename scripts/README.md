# Spanda Platform - Automation Scripts

This directory contains automation scripts for managing the Spanda Platform GitOps configuration.

## 📁 Scripts

### `generate-argocd-applications.sh` / `generate-argocd-applications.ps1`

Automatically generates ArgoCD application YAML files by reading `platform-requirements.yml` from application repositories.

**Features:**
- ✅ Reads `platform-requirements.yml` from app repositories
- ✅ Generates ArgoCD applications for each environment
- ✅ Creates proper namespace mappings (dev → development, etc.)
- ✅ Sets up automatic sync for dev/staging, manual for production
- ✅ Generates documentation for each application

**Usage:**

```bash
# Bash (Linux/macOS/WSL)
./scripts/generate-argocd-applications.sh [repo-url] [repo-url] ...

# PowerShell (Windows)
.\scripts\generate-argocd-applications.ps1 [repo-url] [repo-url] ...

# Examples
./scripts/generate-argocd-applications.sh https://github.com/aryan-spanda/Test-Application.git
./scripts/generate-argocd-applications.sh https://github.com/aryan-spanda/vllm-service.git https://github.com/aryan-spanda/web-dashboard.git
```

**Prerequisites:**
- `yq` - YAML processor
- `git` - Version control

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
