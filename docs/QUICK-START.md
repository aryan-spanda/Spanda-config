# 🚀 Quick Start - Spanda Platform

## **For Application Developers**

### **What You Provide** ✅
1. **Your app source code** (`src/`, `package.json`)
2. **One config file** (`spanda-app.yaml`)
3. **GitHub repo secrets** (Docker Hub credentials)

### **What We Auto-Generate** 🤖
- All Docker files & configurations
- Complete CI/CD pipeline
- Kubernetes deployment manifests
- Package lock files
- Production optimizations

---

## **30-Second Setup**

```bash
# 1. Initialize (creates spanda-app.yaml)
curl -s https://platform.spanda.io/init.sh | bash

# 2. Setup automation (creates all Docker/CI files) 
curl -s https://platform.spanda.io/setup.sh | bash

# 3. Add GitHub secrets:
# DOCKER_HUB_USERNAME + DOCKER_HUB_TOKEN

# 4. Deploy
git add . && git commit -m "Add Spanda Platform" && git push
```

**Done!** Your app automatically builds, deploys, and runs in production. 🎉

---

## **Multi-Service Apps**
Works with any structure:
```
your-app/
├── backend/     # Node.js API
├── frontend/    # React app  
└── database/    # Any service
```

Each service gets its own Docker image and Kubernetes deployment.

---

## **Example spanda-app.yaml**
```yaml
apiVersion: spanda.io/v1
kind: Application
app:
  name: my-app
  version: "1.0.0"
environment: development
platform:
  config_repo: your-org/your-config-repo
  auto_deploy: true
services:
  - name: backend
    port: 8080
    path: /backend
    modules: [database, monitoring]
  - name: frontend  
    port: 3000
    path: /frontend
    modules: [cdn, ssl]
ingress:
  domain: my-app.yourdomain.com
```

---

## **Support**
- 📚 Docs: https://docs.spanda.io
- 💬 Help: https://support.spanda.io
