# 📁 Spanda Platform Scripts Directory

## 🧹 **Cleanup Summary**

**Files Removed (No longer needed):**
- ❌ `client-onboard-self-service.sh` - Old complex client onboarding script
- ❌ `client-onboarding-form.html` - Web form for manual onboarding  
- ❌ `generate-helm-chart.sh` - Complex Helm chart generator
- ❌ `onboard-client.sh` - Manual client onboarding workflow
- ❌ `platform-auto-onboard.sh` - Complex webhook automation
- ❌ `platform-webhook-server.js` - Webhook server for old architecture
- ❌ `update-image.sh` - Kustomize image updater (replaced by GitHub Actions)
- ❌ `validate-kustomize.sh` - Kustomize validator (not using Kustomize anymore)
- ❌ `AUTOMATED-ONBOARDING-SETUP.md` - Setup guide for old complex system

**Reason for removal:** These files were part of the old complex manual/webhook-based system. Our new streamlined automation makes them obsolete.

---

## ✅ **Remaining Essential Scripts**

### **1. `spanda-init.sh`** 
**Purpose:** Initialize new application repositories with Spanda Platform configuration

**What it does:**
- 🎯 Interactive script to generate `spanda-app.yaml` configuration
- 📝 Prompts developers for application details (name, services, modules, etc.)
- 🔧 Creates the single configuration file developers need
- 🎨 Provides smart defaults and validation

**When to use:**
- Developer starting a new application
- Converting existing app to Spanda Platform
- Creating the initial configuration file

**Usage:**
```bash
# In application repository
curl -s https://platform.spanda.io/init.sh | bash
# OR
./spanda-init.sh
```

**Output:** Creates `spanda-app.yaml` with all necessary configuration

---

### **2. `setup-application-repo.sh`**
**Purpose:** Auto-generate all platform integration files for application repositories

**What it does:**
- 🐳 Creates optimized Dockerfiles for all services (root, backend, frontend)
- 🚀 Generates GitHub Actions CI/CD workflow (`auto-deploy-app.yml`)
- 📦 Creates .dockerignore files for build optimization
- 🌐 Generates nginx configuration for frontend services
- 🔒 Creates package-lock.json files if missing
- 📄 Sets up proper .gitignore file

**When to use:**
- After creating `spanda-app.yaml` with `spanda-init.sh`
- Setting up platform automation for existing apps
- Updating platform integration files

**Usage:**
```bash
# In application repository (after spanda-init.sh)
curl -s https://platform.spanda.io/setup.sh | bash
# OR
./setup-application-repo.sh
```

**Output:** Complete platform integration setup ready for deployment

---

### **3. `generate-app-manifests.sh`** 
**Purpose:** Generate Kubernetes manifests from application configuration (config repo side)

**What it does:**
- 📖 Reads `spanda-app.yaml` from application repositories
- 🎛️ Generates Kubernetes deployments, services, ingress, configmaps
- 🏗️ Supports both single-service and multi-service applications
- 🔄 Handles different environments (development, staging, production)
- 📊 Integrates with platform modules (monitoring, database, etc.)

**When to use:**
- Triggered automatically by GitHub Actions `repository_dispatch`
- Manual deployment updates
- Testing manifest generation

**Usage:**
```bash
# In config repository (automated via GitHub Actions)
./generate-app-manifests.sh path/to/spanda-app.yaml staging latest
```

**Output:** Complete Kubernetes manifests in config repository

---

## 🔄 **Complete Automation Flow**

### **Developer Workflow:**
1. **Prepare Code:** `prepare-developer-code.sh` → Creates Dockerfiles and application info
2. **Contact Platform Team:** Send application-info.md to platform team
3. **Wait for Onboarding:** Platform team handles all deployment configuration

### **Platform Team Workflow:**
1. **Receive Request:** Developer sends application information
2. **Onboard Application:** `onboard-client-application.sh` → Creates all platform configs
3. **Deploy:** Commit to config repo → ArgoCD syncs → Application deploys

### **Automated Platform Workflow:**
1. **Monitor:** ArgoCD watches application repositories for changes
2. **Sync:** Automatic deployment when developers push code
3. **Update:** Platform team can update configs as needed

---

## 🎯 **Key Benefits of Streamlined Scripts**

### **Simplicity:**
- ✅ Only 3 scripts vs. 12 complex files
- ✅ Clear separation of concerns
- ✅ Easy to maintain and understand

### **Developer Experience:**
- ✅ Two-step setup: `init` + `setup`
- ✅ Zero infrastructure knowledge required
- ✅ Complete automation after initial setup

### **Platform Benefits:**
- ✅ Consistent deployments across all applications
- ✅ Automatic security and performance optimizations
- ✅ Centralized manifest generation and management

---

## 🚀 **Quick Reference**

| Script | Who Uses | When | Purpose |
|--------|----------|------|---------|
| `spanda-init.sh` | Developers | First time | Create config file |
| `setup-application-repo.sh` | Developers | After init | Setup automation |
| `generate-app-manifests.sh` | Platform (auto) | Every deploy | Generate K8s manifests |

---

## 🆘 **Support Commands**

```bash
# Check script versions
./spanda-init.sh --version
./setup-application-repo.sh --version

# Get help
./spanda-init.sh --help
./setup-application-repo.sh --help

# Validate configuration
./generate-app-manifests.sh --validate spanda-app.yaml
```

## 🚨 **Common Issues**

### **Docker Images Built But Config Repo Not Updated**
**Symptoms:** GitHub Actions shows successful Docker build, but no Kubernetes manifests generated  
**Cause:** Repository dispatch permission issue  
**Solution:** 
1. Check `config_repo` field in `spanda-app.yaml` 
2. Add `PAT_TOKEN` secret if using cross-org repositories
3. See detailed guide: `docs/GITHUB-INTEGRATION.md`

### **Build Fails on Docker Push**
**Symptoms:** "authentication required" or "access denied"  
**Cause:** Missing or invalid Docker Hub credentials  
**Solution:** Add `DOCKER_HUB_USERNAME` and `DOCKER_HUB_TOKEN` secrets

### **Manifest Generation Fails**
**Symptoms:** Config repo workflow triggered but fails to generate YAML  
**Cause:** Invalid `spanda-app.yaml` or missing fields  
**Solution:** Validate config with `spanda-init.sh --validate`

This streamlined approach reduces complexity while maintaining full automation capabilities! 🎉
