# Spanda Platform - Application Onboarding Scripts

This directory contains scripts for onboarding new applications to the Spanda Platform.

## Main Script: `onboard-application.sh`

A general-purpose script that reads `platform-requirements.yml` and creates all necessary GitOps files for deploying applications on the Spanda Platform.

### Usage

```bash
# Option 1: Run from the directory containing platform-requirements.yml
cd /path/to/your-app
/path/to/config-repo/scripts/onboard-application.sh

# Option 2: Specify the path to platform-requirements.yml
/path/to/config-repo/scripts/onboard-application.sh /path/to/your-app/platform-requirements.yml

# Example: Onboard the test-application
cd "C:/Users/aryan/OneDrive/Documents/spanda docs/Test-Application"
"../config-repo/scripts/onboard-application.sh" platform-requirements.yml
```

### Prerequisites

1. **yq** - YAML processor tool
   ```bash
   # Windows (PowerShell)
   curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_windows_amd64.exe -o yq.exe
   
   # Linux
   curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o yq && chmod +x yq
   
   # macOS
   brew install yq
   ```

2. **platform-requirements.yml** - A YAML file describing your application requirements

### What the Script Creates

The script reads your `platform-requirements.yml` and generates:

#### In `config-repo/apps/[app-name]/`:
- **Chart.yaml** - Helm chart definition
- **values.yaml** - Default values
- **values-staging.yaml** - Staging environment configuration
- **values-prod.yaml** - Production environment configuration
- **templates/** - Kubernetes manifest templates
  - deployment.yaml
  - service.yaml
  - ingress.yaml
  - serviceaccount.yaml
  - hpa.yaml
  - configmap.yaml (if needed)
  - _helpers.tpl
- **platform-requirements.yml** - Copy of your original requirements
- **onboard-[app-name].sh** - Application-specific script copy
- **deploy-gitops-template.yml** - GitHub Actions workflow template
- **README.md** - Application documentation

#### In `config-repo/landing-zone/applications/[app-name]/`:
- **staging.yaml** - ArgoCD Application for staging
- **prod.yaml** - ArgoCD Application for production

### Example platform-requirements.yml

```yaml
# Platform Module Requirements
app:
  name: "my-awesome-app"
  environment: "staging"  # staging, production
  
# Frontend Requirements
frontend:
  enabled: true
  framework: "react"
  
  modules:
    external_load_balancer: true
    ssl_termination: true
    cdn: false
    waf: false
    
  config:
    replicas: 2
    port: 3000
    domain: "myapp.example.com"

# Backend Requirements  
backend:
  enabled: true
  framework: "express"
  database: "postgresql"  # none, postgresql, mongodb, redis
  
  modules:
    internal_load_balancer: true
    external_api_access: true
    monitoring: true
    
  config:
    replicas: 3
    port: 5000
    health_check: "/health"
```

### Workflow Integration

After running the script:

1. **Copy the GitHub Actions workflow**:
   ```bash
   cp config-repo/apps/[app-name]/deploy-gitops-template.yml [your-app-repo]/.github/workflows/deploy-gitops.yml
   ```

2. **Ensure your app repo has**:
   - `Dockerfile` (for containerization)
   - `platform-requirements.yml` (your requirements file)

3. **Commit and push config-repo changes**:
   ```bash
   cd config-repo
   git add .
   git commit -m "Add [app-name] application configuration"
   git push
   ```

4. **Your app will be automatically deployed** by ArgoCD when you push code to your application repository.

## Features

### Dynamic Configuration
- **Conditional Templates**: Only creates resources based on your requirements
- **Environment-Specific Values**: Separate configurations for staging and production
- **Framework Detection**: Adapts templates based on frontend/backend frameworks
- **Database Integration**: Configures database connections when specified

### GitOps Ready
- **ArgoCD Applications**: Automatically configured for both environments
- **Image Updater**: Configured for automatic image updates
- **Helm Charts**: Production-ready templates with best practices
- **CI/CD Integration**: Ready-to-use GitHub Actions workflow

### Platform Integration
- **app-of-apps Pattern**: Automatically discovered by existing ArgoCD setup
- **Security Defaults**: Non-root containers, security contexts, read-only filesystems
- **Observability**: Health checks, metrics endpoints, logging configuration
- **Scalability**: HPA configuration, resource limits, multi-replica setup

## Troubleshooting

### Common Issues

1. **yq not found**
   - Install yq following the prerequisites section

2. **Permission denied**
   - On Linux/macOS: `chmod +x onboard-application.sh`
   - On Windows: Run from Git Bash or WSL

3. **Invalid platform-requirements.yml**
   - Ensure `app.name` is specified
   - Check YAML syntax with a validator

4. **Path issues**
   - Use absolute paths when in doubt
   - Check that config-repo path is correct

### Getting Help

- Check the generated `README.md` in your app directory
- Review the application-specific script: `onboard-[app-name].sh`
- Contact the platform team for assistance

## Integration with Existing Platform

This script is designed to work with:
- **ArgoCD app-of-apps** pattern for automatic discovery
- **Spanda Platform bare-metal modules** for infrastructure
- **GitHub Actions reusable workflows** for CI/CD
- **Helm-based deployments** with environment-specific values

The generated applications will be automatically discovered and deployed by the existing `app-of-apps.yaml` configuration.
