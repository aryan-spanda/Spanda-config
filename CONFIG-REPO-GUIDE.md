# Spanda Platform - Config Repository Guide

This repository handles all platform automation for application deployments.

## 🏗️ Repository Structure

```
config-repo/
├── .github/workflows/
│   └── auto-deploy-app.yml          # Auto-deployment workflow
├── scripts/
│   ├── generate-app-manifests.sh    # Manifest generation
│   └── platform-webhook-server.js   # Webhook server
├── apps/                            # Generated app manifests
│   └── {app-name}/
│       ├── namespace.yaml
│       ├── {service}-deployment-{env}.yaml
│       ├── {service}-service-{env}.yaml
│       └── ingress-{env}.yaml
├── landing-zone/applications/       # ArgoCD applications
├── platform/applications/          # Platform module configs
└── cluster-config/                 # Platform infrastructure
```

## 🚀 Automation Flow

### 1. **Application Repository Push**
```
Developer pushes code → GitHub Actions builds images → Triggers config repo
```

### 2. **Config Repository Processing**
```
Receive trigger → Fetch spanda-app.yaml → Generate manifests → Deploy to cluster
```

### 3. **Generated Files**
For each application, the platform automatically generates:

- **Namespace**: `apps/{app-name}/namespace.yaml`
- **Deployments**: `apps/{app-name}/{service}-deployment-{env}.yaml`
- **Services**: `apps/{app-name}/{service}-service-{env}.yaml`
- **Ingress**: `apps/{app-name}/ingress-{env}.yaml`
- **ArgoCD App**: `landing-zone/applications/{app-name}-{env}.yaml`
- **Platform Config**: `platform/applications/{app-name}-platform.yaml`

## 🔧 Key Features

### **Multi-Service Support**
Applications can define multiple services (frontend, backend, API):

```yaml
services:
  - name: "backend"
    port: 8080
    path: "/api"
    dockerfile: "./backend/Dockerfile"
  - name: "frontend"
    port: 80
    path: "/"
    dockerfile: "./frontend/Dockerfile"
```

### **Environment-Specific Configuration**
```yaml
environments:
  staging:
    replicas: 2
    resources:
      cpu: "100m"
      memory: "128Mi"
  production:
    replicas: 10
    resources:
      cpu: "1000m"
      memory: "2Gi"
```

### **Platform Module Integration**
```yaml
platform:
  networking: true      # Load balancer, ingress
  monitoring: true      # Prometheus, Grafana
  security: true        # RBAC, network policies
  logging: true         # Centralized logging
```

## 📋 Required Secrets

Add these secrets to the config repository:

- `KUBECONFIG` - Base64 encoded kubeconfig for cluster access
- `GITHUB_TOKEN` - GitHub token for repository access
- `GITOPS_PAT` - Personal access token for GitOps operations

## 🔄 Deployment Process

### **Automatic Trigger**
1. Application repo pushes code
2. Builds and pushes Docker images
3. Sends repository_dispatch to config repo
4. Config repo auto-deploys application

### **Manual Trigger**
```bash
# Trigger deployment manually
gh workflow run auto-deploy-app.yml \
  --field app_repo_url="https://github.com/user/app" \
  --field environment="staging"
```

## 📊 Monitoring Deployments

### **GitHub Actions**
Monitor deployments at:
- https://github.com/aryan-spanda/Spanda-config/actions

### **ArgoCD Dashboard**
View application status:
- https://argocd.yourdomain.com

### **Kubernetes Resources**
```bash
# Check application namespace
kubectl get ns {app-name}-{environment}

# View application resources
kubectl get all -n {app-name}-{environment}

# Check ArgoCD application
kubectl get application {app-name}-{environment} -n argocd
```

## 🛠️ Troubleshooting

### **Deployment Fails**
1. Check GitHub Actions logs
2. Verify spanda-app.yaml syntax
3. Check cluster resource quotas
4. Validate image repositories exist

### **ArgoCD Sync Issues**
```bash
# Force sync ArgoCD application
kubectl patch application {app-name}-{environment} -n argocd \
  --type='merge' -p='{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```

### **Image Pull Errors**
- Verify Docker Hub credentials
- Check image repository names
- Ensure images are public or secrets are configured

## 🔧 Maintenance

### **Adding New Platform Modules**
1. Update `generate-app-manifests.sh`
2. Add module templates
3. Update platform configuration

### **Updating Automation**
1. Modify `.github/workflows/auto-deploy-app.yml`
2. Update manifest generation scripts
3. Test with sample applications

## 📞 Support

- **Platform Team**: platform@yourcompany.com
- **Documentation**: https://docs.spanda-platform.com
- **Issues**: Create GitHub issue in this repository
