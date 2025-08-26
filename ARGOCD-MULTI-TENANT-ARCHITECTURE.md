# 🔐 ArgoCD Multi-Tenant Architecture

## Overview

The Spanda AI Platform now supports multiple ArgoCD projects with different security models:

## 📂 ArgoCD Projects

### 1. **spanda-platform** (Platform Services Only)
- **Purpose**: Deploy platform infrastructure and shared services
- **Source Repos**: Restricted to `aryan-spanda/*` GitHub organization
- **Destinations**: Platform namespaces only (`argocd`, `platform-*`, `monitoring`, etc.)
- **Permissions**: Full cluster-level resources (CRDs, ClusterRoles, etc.)

### 2. **spanda-applications** (Legacy Client Applications)
- **Purpose**: Backward compatibility for existing client applications
- **Source Repos**: Any repository (`*` - allows client repos)
- **Destinations**: Application namespaces (`development`, `staging`, `production`, `*-dev`, `*-staging`, `*-prod`)
- **Permissions**: Namespace-level resources only

### 3. **Tenant-Specific Projects** (New Multi-Tenant Model)
- **Purpose**: Isolated deployment environments for each tenant
- **Source Repos**: Restricted to tenant's GitHub organization
- **Destinations**: Only tenant's namespaces (`{tenant}-dev`, `{tenant}-staging`, `{tenant}-prod`)
- **Permissions**: Namespace-level resources within tenant namespaces only

## 🚀 Migration Path

### Current State: Backward Compatible
- ✅ Existing applications continue to work with `spanda-applications` project
- ✅ New tenant-aware applications use tenant-specific projects
- ✅ Platform services use `spanda-platform` project

### For New Applications (Recommended)
```yaml
# platform-requirements.yml
app:
  name: "my-app"
  tenant: "acme-corp"  # Use tenant-specific project
```

### For Existing Applications (Legacy Support)
```yaml
# platform-requirements.yml  
app:
  name: "my-app"
  # No tenant field = uses spanda-applications project
```

## 🏗️ Tenant Onboarding Process

1. **Deploy Tenant Infrastructure**:
   ```bash
   cd bare-metal/examples/tenant-onboarding
   terraform apply
   ```

2. **Creates**:
   - Tenant namespaces (`{tenant}-dev`, `{tenant}-staging`, `{tenant}-prod`)
   - ArgoCD project for tenant
   - Resource quotas and network policies
   - Service accounts with RBAC

3. **Tenant Applications Deploy**:
   - From tenant's GitHub organization
   - To tenant's namespaces only
   - With enforced resource limits

## 🔒 Security Model

### Tenant Isolation
- Each tenant has their own ArgoCD project
- Can only deploy from their GitHub organization
- Can only deploy to their own namespaces
- Network policies prevent cross-tenant access

### Platform Security
- Platform services have separate project
- Only platform team can deploy platform services
- Full cluster access for infrastructure management

### Legacy Support
- Existing applications keep working
- Gradual migration to tenant model
- No breaking changes for current deployments

## 📝 Examples

### Platform Service Deployment
```yaml
# Uses spanda-platform project
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: monitoring-stack
spec:
  project: spanda-platform
  destination:
    namespace: monitoring
```

### Tenant Application Deployment
```yaml
# Uses acme-corp project (created by tenant factory)
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: acme-app-dev
spec:
  project: acme-corp
  destination:
    namespace: acme-corp-dev
```

### Legacy Application Deployment
```yaml
# Uses spanda-applications project
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: legacy-app-dev
spec:
  project: spanda-applications
  destination:
    namespace: development
```

This architecture provides **security**, **backward compatibility**, and **tenant isolation** all at the same time! 🎉
