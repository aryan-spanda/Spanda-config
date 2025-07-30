# 🔧 GitHub Integration Setup Guide

## 🔑 Required GitHub Secrets

### **Application Repository Secrets:**

#### **1. DOCKER_HUB_USERNAME** ✅ REQUIRED
- **Purpose:** Login to Docker Hub for pushing images
- **Value:** Your Docker Hub username
- **Example:** `aryanspanda`

#### **2. DOCKER_HUB_TOKEN** ✅ REQUIRED  
- **Purpose:** Authenticate with Docker Hub
- **Value:** Docker Hub access token (not password!)
- **How to get:**
  1. Go to Docker Hub → Account Settings → Security
  2. Create new access token
  3. Copy the token value

#### **3. GITHUB_TOKEN** 🔄 AUTO-CONFIGURED
- **Purpose:** Trigger config repository deployment
- **Value:** Automatically provided by GitHub Actions
- **Permissions needed:** `repository_dispatch` on config repository

---

## ⚙️ GitHub Token Permissions

### **Issue: Config Repository Not Triggered**

If your application builds successfully but doesn't trigger the config repository, the issue is likely permissions.

### **Solution Options:**

#### **Option A: Use Organization/Team Setup (Recommended)**
If both repositories are in the same organization:
1. The default `GITHUB_TOKEN` should work
2. Ensure the config repository allows repository dispatch from application repo

#### **Option B: Use Personal Access Token**
If repositories are in different organizations or default token doesn't work:

1. **Create Personal Access Token:**
   - Go to GitHub → Settings → Developer settings → Personal access tokens
   - Create token with these permissions:
     - `repo` (full repository access)
     - `workflow` (update workflows)

2. **Add as Secret:**
   - In application repository → Settings → Secrets → Actions
   - Add secret named `PAT_TOKEN`
   - Value: Your personal access token

3. **Update Workflow:**
   ```yaml
   - name: Trigger config repository deployment
     run: |
       curl -X POST \
         -H "Authorization: token ${{ secrets.PAT_TOKEN }}" \
   ```

---

## 🚨 Common Issues & Solutions

### **Issue 1: 403 Forbidden**
```
HTTP Response Code: 403
Response: {"message": "Resource not accessible by integration"}
```

**Cause:** GITHUB_TOKEN doesn't have permission to trigger repository_dispatch  
**Solution:** Use Personal Access Token (Option B above)

### **Issue 2: 404 Not Found**
```
HTTP Response Code: 404
Response: {"message": "Not Found"}
```

**Cause:** Config repository URL is wrong or not accessible  
**Solution:** Check `config_repo` field in `spanda-app.yaml`

### **Issue 3: Build Successful but No Deployment**
**Cause:** Config repository workflow not triggered  
**Solution:** Check GitHub Actions logs in config repository

---

## 📋 Setup Checklist

### **Application Repository:**
- [ ] `DOCKER_HUB_USERNAME` secret added
- [ ] `DOCKER_HUB_TOKEN` secret added  
- [ ] `spanda-app.yaml` has correct `config_repo` field
- [ ] GitHub Actions workflow file created
- [ ] Repository has push access to config repo (or PAT_TOKEN)

### **Config Repository:**
- [ ] Has workflow that handles `repository_dispatch`
- [ ] Event type matches: `deploy-application`
- [ ] `generate-app-manifests.sh` script exists and is executable
- [ ] ArgoCD applications directory exists

---

## 🧪 Testing the Integration

### **1. Manual Test (Application Repo):**
```bash
# Push a change to trigger the workflow
git add .
git commit -m "Test deployment trigger"
git push origin main
```

### **2. Manual Test (Config Repo):**
```bash
# Test workflow manually
gh workflow run auto-deploy-app.yml \
  -f app_repo_url="https://github.com/your-org/your-app" \
  -f environment="staging"
```

### **3. Check Logs:**
- Application repo: Check if "Trigger config repository deployment" step succeeds
- Config repo: Check if workflow is triggered and manifests are generated

---

## 🎯 Expected Flow

1. **Developer pushes to app repo** → Application workflow runs
2. **Docker images built and pushed** → Images go to Docker Hub  
3. **Repository dispatch sent** → Config repo workflow triggered
4. **Manifests generated** → Kubernetes YAML files created
5. **ArgoCD syncs** → Application deployed to cluster

If any step fails, check the corresponding logs and secrets! 🔍
