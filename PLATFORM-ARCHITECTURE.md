# SPANDA AI PLATFORM - DEPLOYMENT ARCHITECTURE

## 🏗️ Two-Layer Architecture Overview

We use a **two-layer deployment architecture** for better separation of concerns:

### **Layer 1: Platform Infrastructure (Spanda Terraform Repo)**
- **Repository**: `spandaai-platform-terraform-deployment`
- **Purpose**: Deploy stable, shared platform services once
- **Deployment**: Direct from source repo using `deploy-complete-platform.sh`
- **Services**: MetalLB, networking, security, load balancers

### **Layer 2: Applications (Config Repo)**  
- **Repository**: `config-repo` (this repo)
- **Purpose**: Deploy business applications that consume platform services
- **Deployment**: GitOps via ArgoCD using `generate-argocd-applications-simple.sh`
- **Services**: Your actual applications (Test-Application, etc.)

## 🚀 Deployment Workflow

### **Step 1: Deploy Platform Services**
```bash
# From spanda terraform repo
cd spandaai-platform-deployment/bare-metal
./deploy-complete-platform.sh
```

**This creates:**
- ✅ MetalLB address management
- ✅ VPC networking configuration  
- ✅ Security policies and firewall
- ✅ Load balancers (general, external, internal)
- ✅ All services running and ready for consumption

### **Step 2: Discover Available Services**
```bash
# Check what platform services are available
./discover-platform-services.sh

# Validate specific application requirements
./discover-platform-services.sh ../config-repo/local-app-repos/Test-Application/platform-requirements.yml
```

### **Step 3: Generate Application Manifests**
```bash
# From config repo
cd config-repo/scripts
./generate-argocd-applications-simple.sh
```

**This generates:**
- ✅ ArgoCD application manifests for each app/environment
- ✅ Service discovery ConfigMaps
- ✅ Platform service endpoint configurations
- ✅ Automatic validation of platform requirements

### **Step 4: Deploy Applications**
```bash
# Deploy all applications via ArgoCD
kubectl apply -f ../applications/
```

## 🎯 How Applications Discover Platform Services

### **1. Service Discovery ConfigMap**
Each application gets a ConfigMap with platform service endpoints:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-application-platform-services
data:
  PLATFORM_LOAD_BALANCER: "general-lb.platform-networking.svc.cluster.local"
  PLATFORM_EXTERNAL_LB: "external-lb.platform-networking.svc.cluster.local" 
  PLATFORM_INTERNAL_LB: "internal-lb.platform-networking.svc.cluster.local"
```

### **2. Kubernetes Native Service Discovery**
Applications can discover services using standard Kubernetes DNS:
```bash
# From within any pod
curl http://external-lb.platform-networking.svc.cluster.local
curl http://internal-lb.platform-networking.svc.cluster.local
```

### **3. Platform Requirements Validation**
Applications declare requirements in `platform-requirements.yml`:
```yaml
platform:
  modules:
    address_management: true      # MetalLB
    vpc_networking: true          # Network policies  
    external_load_balancer: true  # Public access
    internal_load_balancer: true  # Internal routing
    firewall: true               # Security
```

The deployment scripts automatically validate these requirements against available services.

## 📁 File Structure After Cleanup

### **Spanda Terraform Repo (Platform Layer)**
```
spandaai-platform-deployment/
├── bare-metal/
│   ├── deploy-complete-platform.sh    # 🆕 Main platform deployment
│   ├── scripts/
│   │   └── discover-platform-services.sh  # 🆕 Service discovery
│   └── modules/
│       ├── net-address-baremetal/
│       ├── net-vpc-baremetal/
│       ├── net-firewall-baremetal/
│       ├── net-lb-baremetal/
│       ├── net-lb-app-external-baremetal/
│       └── net-lb-app-internal-baremetal/
```

### **Config Repo (Application Layer)**
```  
config-repo/
├── scripts/
│   ├── generate-argocd-applications-simple.sh  # 🔄 Updated with validation
│   ├── main.sh                                 # Main orchestration
│   └── sync-app-repos.sh                      # App repo sync
├── applications/                               # Generated ArgoCD apps
├── local-app-repos/                           # Local app copies
└── argocd/                                    # ArgoCD configuration
```

## ✅ Benefits of This Architecture

### **🎯 Stability and Speed**
- Platform deployed once, applications deploy fast
- No waiting for infrastructure provisioning per application
- Predictable, stable environment for all teams

### **🔄 Clear Separation of Concerns**  
- Platform team manages infrastructure (Layer 1)
- Development teams focus on applications (Layer 2)
- Clean boundaries and responsibilities

### **📦 Service Catalog Approach**
- Applications consume services, not deploy infrastructure
- Shared services reduce resource usage and complexity
- Consistent platform capabilities across all environments

### **🔍 Automatic Discovery**
- Applications automatically discover available services
- Validation ensures requirements are met before deployment
- No manual configuration of service endpoints

## 🚀 Getting Started

1. **Deploy Platform**: `cd spandaai-platform-deployment/bare-metal && ./deploy-complete-platform.sh`
2. **Verify Services**: `./discover-platform-services.sh`
3. **Generate Apps**: `cd config-repo/scripts && ./generate-argocd-applications-simple.sh`
4. **Deploy Apps**: `kubectl apply -f ../applications/`

**Platform is now ready for application deployments!** 🎉
