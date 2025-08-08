# SPANDA AI PLATFORM - PLATFORM SERVICES DEPLOYMENT GUIDE

## 🎯 **Two-Layer Architecture Overview**

Your platform now implements a clean **two-layer architecture**:

### **🏗️ Layer 1: Platform Services (Deploy Once)**
- Persistent infrastructure services shared by all applications
- Deployed from your private repository: `spandaai/spandaai-platform-terraform-deployment`
- Includes: networking, load balancers, security, address management

### **🚀 Layer 2: Applications (Deploy Many)**
- Individual applications that consume platform services
- Simple, fast deployments without infrastructure provisioning
- Each application gets its own ArgoCD application manifest

---

## 📋 **Prerequisites**

1. **Clean Platform Infrastructure Deployed**: 
   ```bash
   ./deploy-baremetal-complete-clean.sh
   ```

2. **ArgoCD Access**: http://172.18.255.230 (admin/S68NguPwt7NyBKnB)

3. **Required Tools**: `yq`, `kubectl`, `bash`

4. **Private Repository Access**: Configure in ArgoCD UI

---

## 🚀 **Deployment Workflow**

### **Step 1: Configure Private Repository Access**

1. **Access ArgoCD**: http://172.18.255.230
2. **Login**: admin / S68NguPwt7NyBKnB
3. **Go to**: Settings → Repositories
4. **Add Repository**:
   - **Repository URL**: `https://github.com/spandaai/spandaai-platform-terraform-deployment.git`
   - **Username**: Your GitHub username
   - **Password**: GitHub Personal Access Token
   - **Project**: spanda-applications

### **Step 2: Deploy Platform Services (One Time)**

```bash
cd "C:\Users\aryan\OneDrive\Documents\spanda docs\config-repo"

# Deploy all platform modules as persistent services
./scripts/deploy-platform-services.sh deploy
```

**This will create ArgoCD applications for**:
- `platform-address-management` (MetalLB, External-DNS)
- `platform-vpc-networking` (VPC networking)
- `platform-firewall` (Security rules)
- `platform-external-load-balancer` (Public traffic)
- `platform-internal-load-balancer` (Internal traffic)
- `platform-load-balancer` (General purpose)

### **Step 3: Verify Platform Services**

```bash
# Check platform service status
./scripts/deploy-platform-services.sh status

# View ArgoCD applications
kubectl get applications -n argocd -l app.kubernetes.io/component=infrastructure

# Check platform pods
kubectl get pods -n platform-networking -l app.kubernetes.io/part-of=spandaai-platform
```

### **Step 4: Generate Application Manifests**

```bash
# Generate simple applications (no platform modules embedded)
./scripts/generate-argocd-applications-simple.sh
```

### **Step 5: Deploy All Applications (Platform + Business Apps)**

```bash
# Deploy everything from applications directory
kubectl apply -f applications/ -R

# Or deploy selectively:
kubectl apply -f applications/platform-services/     # Infrastructure first
kubectl apply -f applications/Test-Application/      # Then applications
```

---

## 📊 **What Gets Deployed**

### **🏗️ Platform Services (Persistent)**
| Service | Namespace | Priority | Description |
|---------|-----------|----------|-------------|
| platform-address-management | platform-networking | 10 | MetalLB IP pools, External-DNS |
| platform-vpc-networking | platform-networking | 15 | VPC networking configuration |
| platform-firewall | platform-security | 20 | Security rules and policies |
| platform-load-balancer | platform-networking | 25 | General purpose load balancer |
| platform-external-load-balancer | platform-networking | 30 | Public traffic load balancer |
| platform-internal-load-balancer | platform-networking | 35 | Internal traffic load balancer |

### **🚀 Applications (Dynamic)**
- Simple ArgoCD applications
- Consume existing platform services
- Fast deployment (no infrastructure provisioning)
- Environment-specific configurations

---

## 🔧 **Management Commands**

### **Platform Services Management**
```bash
# Deploy platform services
./scripts/deploy-platform-services.sh deploy

# Check status
./scripts/deploy-platform-services.sh status

# Remove all platform services
./scripts/deploy-platform-services.sh cleanup
```

### **Application Management**
```bash
# Generate application manifests
./scripts/generate-argocd-applications-simple.sh

# List applications
kubectl get applications -n argocd

# Sync specific application
kubectl patch application test-application-dev -n argocd -p '{"operation":{"sync":{}}}' --type merge
```

### **Namespace Management**
```bash
# Create namespace for new application
cd ../spandaai-platform-deployment
./manage-namespaces.sh create myapp development
./manage-namespaces.sh create-with-rbac myapp production
```

---

## 🎯 **Benefits of This Architecture**

### **✅ For Platform Services:**
- **Deploy Once**: Platform modules deployed as persistent services
- **Shared Resources**: All applications use the same infrastructure
- **Cost Efficient**: No duplicate resources per application
- **Centralized Management**: Platform team controls infrastructure
- **Service Catalog**: Ready-to-use platform capabilities

### **✅ For Applications:**
- **Fast Deployment**: No waiting for infrastructure provisioning
- **Simple Configuration**: Just the application, no complex multi-source
- **Independent Lifecycle**: Applications can be updated independently
- **Team Autonomy**: Application teams focus on their applications
- **GitOps Ready**: Full ArgoCD integration with image auto-updates

---

## 🔍 **Troubleshooting**

### **Platform Services Issues**
```bash
# Check ArgoCD applications
kubectl get applications -n argocd -l app.kubernetes.io/component=infrastructure

# Check specific platform service
kubectl describe application platform-address-management -n argocd

# Check platform pods
kubectl get pods -n platform-networking
kubectl get pods -n platform-security
```

### **Application Issues**
```bash
# Check application status
kubectl get applications -n argocd -l app.kubernetes.io/part-of=spandaai-applications

# Check application pods
kubectl get pods -n development
kubectl get pods -n staging
kubectl get pods -n production
```

### **Repository Access Issues**
1. Verify repository credentials in ArgoCD UI
2. Check repository connection: Settings → Repositories
3. Ensure GitHub PAT has required permissions

---

## 📁 **File Structure**

```
config-repo/
├── scripts/
│   ├── deploy-platform-services.sh              # Deploy platform services
│   └── generate-argocd-applications-simple.sh   # Generate app manifests
├── cluster-config/
│   └── config/
│       └── module-mappings.yml                  # Platform module definitions
└── applications/                                # All ArgoCD applications
    ├── platform-services/                      # Infrastructure services
    │   ├── address_management.yaml              # MetalLB, External-DNS
    │   ├── vpc_networking.yaml                  # VPC networking
    │   ├── firewall.yaml                       # Security rules
    │   ├── external_load_balancer.yaml         # Public traffic LB
    │   ├── internal_load_balancer.yaml         # Internal traffic LB
    │   └── load_balancer.yaml                  # General purpose LB
    └── Test-Application/                        # Business applications
        └── argocd/
            ├── app-dev.yaml                     # Test app - development
            ├── app-staging.yaml                 # Test app - staging
            └── app-production.yaml             # Test app - production
```

---

## 🚀 **Ready to Deploy!**

Your platform is now configured for the **two-layer architecture**:

1. **Deploy platform services once** using the deploy script
2. **Generate and deploy applications** using the simple generator
3. **Applications consume existing platform services** for fast deployment

This gives you the **best of both worlds**: centralized platform management with fast application deployment! 🎉
