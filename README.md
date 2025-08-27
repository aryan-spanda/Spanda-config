# 🚀 Spanda Platform - Configuration Repository

**GitOps-based multi-tenant platform for automated application deployment using ArgoCD.**

## 🏗️ Architecture Overview

### **Two-Layer Deployment Model**

#### **Layer 1: Platform Infrastructure** 
- **Repository**: `spandaai-platform-deployment` 
- **Purpose**: Deploy shared platform services once (MetalLB, networking, security)
- **Method**: Direct Terraform deployment

#### **Layer 2: Applications**
- **Repository**: `config-repo` (this repo)  
- **Purpose**: Deploy tenant applications that consume platform services
- **Method**: GitOps via ArgoCD

### **Multi-Tenant Security Model**
- **`spanda-platform`**: Platform services with cluster-level access
- **`spanda-applications`**: Legacy applications with namespace-level access  
- **`{tenant-name}`**: Tenant-specific projects with isolated namespaces

## 📁 Repository Structure

```
config-repo/
├── 🚀 applications/                    # ArgoCD Application definitions
│   └── Test-Application/argocd/        # Generated tenant applications
├── ⚙️ argocd/projects/                 # ArgoCD project configurations  
├── 🏢 tenants/tenant-sources.yml       # Multi-tenant configuration
├── 🔧 scripts/                        # Automation scripts
│   ├── generate-argocd-applications-simple.sh  # App generation
│   └── main.sh                        # Main orchestration
├── 📋 application-sources.txt          # Application repositories
└── 🔑 argocd-image-updater-git-secret.yaml  # Git credentials
```

## 🚀 Quick Start Guide

### **Prerequisites**
- Kubernetes cluster with ArgoCD deployed
- `yq`, `kubectl`, `bash` installed
- GitHub Personal Access Token

### **Step 1: Install Dependencies**
```bash
# Windows (PowerShell)
winget install mikefarah.yq

# Or using WSL
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

### **Step 2: Deploy Platform Infrastructure** 
```bash
cd ../spandaai-platform-deployment/bare-metal
./deploy-baremetal-complete-clean.sh
```

### **Step 3: Create New Tenant**
```bash
# Edit tenant configuration
vim tenants/tenant-sources.yml

# Add new tenant:
tenants:
  - name: "my-tenant"
    git_org: "my-org"  
    cpu_quota: "20"
    memory_quota: "40Gi"
    storage_quota: "100Gi"
    environments: ["dev", "staging", "prod"]

# Deploy tenant infrastructure
cd ../spandaai-platform-deployment/bare-metal/examples/tenant-onboarding
terraform apply -var="tenants_file=../../../config-repo/tenants/tenant-sources.yml"
```

### **Step 4: Onboard Application**
```bash
# Add application repository
echo "https://github.com/my-org/my-app/tree/testing" >> application-sources.txt

# Ensure app has platform-requirements.yml:
app:
  name: "my-app"
  tenant: "my-tenant"  # Maps to tenant project
  type: "fullstack" 
  team: "dev-team"
environments: ["dev", "staging", "prod"]

# Generate ArgoCD applications  
./scripts/generate-argocd-applications-simple.sh

# Deploy applications
kubectl apply -f applications/My-App/argocd/
```

## 🔄 Automation Workflows

### **Application Generation**
The `generate-argocd-applications-simple.sh` script:
- ✅ Reads `application-sources.txt` 
- ✅ Fetches `platform-requirements.yml` from GitHub
- ✅ Auto-discovers microservices in `src/*/Dockerfile`
- ✅ Generates tenant-aware ArgoCD applications
- ✅ Configures ArgoCD Image Updater for automatic deployments

### **Image Update Automation**
```yaml
# Automatic image tag updates on commit
argocd-image-updater.argoproj.io/image-list: backend=aryanpola/sample-application,frontend=aryanpola/sample-application
argocd-image-updater.argoproj.io/backend.allow-tags: regexp:^backend-[0-9a-f]{7,40}$
argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/argocd-image-updater-git
```

### **Expected CI/CD Tags**
```bash
# For each microservice, build with SHA-based tags:
aryanpola/sample-application:backend-abc123f   # Backend service
aryanpola/sample-application:frontend-def456a  # Frontend service  
aryanpola/sample-application:api-xyz789b       # API service
```

## 🔑 Security & RBAC

### **Tenant Isolation**
Each tenant gets:
- **Dedicated namespaces**: `{tenant}-{env}` (e.g., `acme-corp-dev`)
- **Resource quotas**: CPU, memory, storage limits
- **Network policies**: Isolated network segments  
- **Service accounts**: `{tenant}-automation` with namespace-level permissions
- **ArgoCD project**: Can only deploy from tenant's GitHub org

### **Secrets Management**
- **ArgoCD Image Updater**: Uses `argocd-image-updater-git-secret.yaml` for Git write-back
- **Repository Access**: Configure private repos in ArgoCD UI
- **Tenant Secrets**: Managed within tenant namespaces

## 📊 Operational Commands

### **Tenant Management**
```bash
# List all tenants
kubectl get namespaces -l spanda.ai/managed-by=tenant-factory

# Check tenant resources
kubectl get resourcequotas -n my-tenant-dev
kubectl get networkpolicies -n my-tenant-dev  
kubectl get serviceaccounts -n my-tenant-dev

# View tenant ArgoCD project
kubectl get appproject my-tenant -n argocd
```

### **Application Management**
```bash
# List all applications
kubectl get applications -n argocd

# Check application status
kubectl get app my-app-dev -n argocd

# Force sync application
kubectl patch app my-app-dev -n argocd -p '{"operation":{"sync":{}}}' --type merge

# View application logs
kubectl logs -n my-tenant-dev deployment/my-app-backend
```

### **Platform Services**
```bash
# Check platform infrastructure
kubectl get pods -n platform-networking
kubectl get pods -n platform-security  
kubectl get pods -n platform-data

# View ArgoCD projects
kubectl get appprojects -n argocd
```

## 🎯 Benefits

### **For Platform Teams**
- ✅ **Centralized Control**: Single source of truth for all deployments
- ✅ **Multi-Tenant Security**: Isolated tenant environments with RBAC
- ✅ **Automated Onboarding**: Script-driven tenant and application onboarding
- ✅ **GitOps Workflow**: All changes tracked and auditable

### **For Development Teams**  
- ✅ **Self-Service**: Add applications via simple configuration
- ✅ **Automatic Deployments**: Image updates trigger automatic deployments
- ✅ **Microservice Support**: Auto-discovery of services in repository
- ✅ **Environment Consistency**: Same configuration across dev/staging/prod

### **For Operations**
- ✅ **Resource Governance**: Tenant quotas prevent resource exhaustion
- ✅ **Network Security**: Isolated tenant networks with policies
- ✅ **Observability**: Rich metadata and monitoring integration
- ✅ **Disaster Recovery**: Git-based infrastructure enables quick recovery

## 🆘 Troubleshooting

### **Common Issues**

#### Missing Dependencies
```bash
# Check required tools
yq --version
kubectl version --client
curl --version

# Install missing tools
winget install mikefarah.yq  # Windows
brew install yq             # macOS  
sudo apt install yq         # Ubuntu
```

#### Application Generation Failures
```bash
# Check platform-requirements.yml format
yq eval . Test-Application/platform-requirements.yml

# Verify repository access
curl -s https://api.github.com/repos/my-org/my-app/contents/platform-requirements.yml

# Check application-sources.txt format
cat application-sources.txt
```

#### ArgoCD Sync Issues
```bash
# Check application events
kubectl describe app my-app-dev -n argocd

# View ArgoCD logs  
kubectl logs -n argocd deployment/argocd-application-controller

# Check Image Updater logs
kubectl logs -n argocd deployment/argocd-image-updater
```

#### Tenant Access Issues
```bash
# Verify tenant project permissions
kubectl describe appproject my-tenant -n argocd

# Check namespace RBAC
kubectl describe role my-tenant-automation -n my-tenant-dev

# Validate resource quotas
kubectl describe resourcequota -n my-tenant-dev
```

---

**🎉 Ready to deploy? Start with the Quick Start Guide above!**

