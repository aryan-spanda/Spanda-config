# 📋 Developer Requirements - Spanda Platform

This document outlines exactly what application developers need to provide vs. what the Spanda Platform automatically generates.

## 🎯 **What Developers Must Provide**

### **1. Application Code** ✅ REQUIRED
```
your-app/
├── src/                    # ← Your application source code
├── package.json           # ← Dependencies and scripts
└── README.md             # ← Project documentation
```

### **2. Multi-Service Applications** ✅ REQUIRED (if applicable)
```
your-app/
├── backend/
│   ├── src/              # ← Backend source code
│   └── package.json      # ← Backend dependencies
└── frontend/
    ├── src/              # ← Frontend source code
    ├── public/           # ← React public files
    └── package.json      # ← Frontend dependencies
```

### **3. Configuration File** ✅ REQUIRED
```yaml
# spanda-app.yaml - Single configuration file
apiVersion: spanda.io/v1
kind: Application

app:
  name: my-awesome-app
  description: "My application description"
  version: "1.0.0"

environment: development

platform:
  config_repo: aryan-spanda/Spanda-config
  auto_deploy: true

# ... rest of configuration
```

## 🤖 **What Platform Auto-Generates**

### **1. Docker Files** 🔧 AUTO-GENERATED
The platform automatically creates optimized Docker configurations:

```
your-app/
├── Dockerfile             # ← AUTO-GENERATED
├── .dockerignore         # ← AUTO-GENERATED
├── backend/
│   ├── Dockerfile        # ← AUTO-GENERATED
│   └── .dockerignore     # ← AUTO-GENERATED
└── frontend/
    ├── Dockerfile        # ← AUTO-GENERATED
    ├── .dockerignore     # ← AUTO-GENERATED
    └── nginx.conf        # ← AUTO-GENERATED
```

### **2. CI/CD Pipeline** 🔧 AUTO-GENERATED
```
your-app/
└── .github/workflows/
    └── auto-deploy-app.yml  # ← AUTO-GENERATED
```

### **3. Package Lock Files** 🔧 AUTO-GENERATED
```
your-app/
├── package-lock.json        # ← AUTO-GENERATED
├── backend/package-lock.json # ← AUTO-GENERATED
└── frontend/package-lock.json # ← AUTO-GENERATED
```

### **4. Kubernetes Manifests** 🔧 AUTO-GENERATED
Generated in the config repository:
```
config-repo/
└── apps/your-app/
    ├── deployment.yaml      # ← AUTO-GENERATED
    ├── service.yaml         # ← AUTO-GENERATED
    ├── ingress.yaml         # ← AUTO-GENERATED
    └── configmap.yaml       # ← AUTO-GENERATED
```

## 🚀 **Developer Workflow**

### **Step 1: Initialize Your App**
```bash
# In your application repository
curl -s https://platform.spanda.io/init.sh | bash
# OR
spanda init
```

### **Step 2: Setup Platform Integration**
```bash
# Run the setup script
curl -s https://platform.spanda.io/setup.sh | bash
# OR  
spanda setup
```

### **Step 3: Configure GitHub Secrets**
Add these secrets to your GitHub repository:
- `DOCKER_HUB_USERNAME`
- `DOCKER_HUB_TOKEN`

### **Step 4: Deploy** 
```bash
git add .
git commit -m "Add Spanda Platform integration"
git push origin main
```

**That's it!** 🎉 Your application will automatically:
1. Build Docker images
2. Push to Docker Hub
3. Generate Kubernetes manifests
4. Deploy via ArgoCD

## 📁 **Final Repository Structure**

### **Before Platform Integration**
```
your-app/                    # What developer starts with
├── src/
├── package.json
└── README.md
```

### **After Platform Integration** 
```
your-app/                    # What developer has after setup
├── src/                     # ← DEVELOPER PROVIDED
├── package.json             # ← DEVELOPER PROVIDED  
├── spanda-app.yaml         # ← DEVELOPER PROVIDED (via init)
├── README.md               # ← DEVELOPER PROVIDED
├── Dockerfile              # ← AUTO-GENERATED
├── .dockerignore           # ← AUTO-GENERATED
├── package-lock.json       # ← AUTO-GENERATED
└── .github/workflows/
    └── auto-deploy-app.yml # ← AUTO-GENERATED
```

## 🔄 **Continuous Updates**

The platform automatically handles:
- ✅ Docker security updates
- ✅ CI/CD pipeline improvements  
- ✅ Kubernetes manifest optimizations
- ✅ New platform features

Developers **never** need to:
- ❌ Write Dockerfile configurations
- ❌ Manage CI/CD pipelines
- ❌ Create Kubernetes manifests
- ❌ Handle deployment orchestration

## 🆘 **Support Commands**

```bash
# Check platform status
spanda status

# Update platform integration
spanda update

# View deployment logs
spanda logs

# Rollback deployment
spanda rollback

# Remove platform integration
spanda remove
```

---

## 📞 **Need Help?**

- 📚 **Documentation**: https://docs.spanda.io
- 💬 **Support**: https://support.spanda.io  
- 🐛 **Issues**: https://github.com/spanda-platform/issues
