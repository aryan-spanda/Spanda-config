# Tenants

This directory manages all tenant configurations and infrastructure for the Spanda AI Platform's multi-tenant environment.

## 📁 Structure

```
tenants/
├── README.md                 # This documentation
├── tenant-sources.yml        # Master tenant configuration file
└── infrastructure/           # Terraform infrastructure for tenant provisioning
    ├── main.tf              # Entry point for tenant factory
    ├── variables.tf         # Input variables
    ├── outputs.tf           # Terraform outputs
    └── tenant-factory/      # Reusable tenant module
        ├── main.tf          # Core tenant resources
        ├── variables.tf     # Module variables
        └── outputs.tf       # Module outputs
```

## 🎯 Quick Start

### Adding a New Tenant

1. **Edit tenant configuration:**
   ```bash
   # Edit the tenant-sources.yml file
   vi tenant-sources.yml
   ```

2. **Add tenant entry:**
   ```yaml
   tenants:
     - name: "your-tenant-name"
       git_org: "your-github-org"
       description: "Description of your tenant"
       cpu_quota: "20"
       memory_quota: "40Gi"
       storage_quota: "100Gi"
       gpu_quota: "1"          # Set to "0" to disable GPU access
       environments: ["dev", "staging", "production"]
   ```

3. **Run onboarding script:**
   ```bash
   cd ../scripts
   ./onboard-tenants.sh
   ```

## 📋 Configuration Reference

### tenant-sources.yml

The master configuration file that defines all tenants and their resource allocations.

#### Tenant Properties

| Property | Description | Example | Required |
|----------|-------------|---------|:--------:|
| `name` | Unique tenant identifier (lowercase, hyphenated) | `"my-company"` | ✅ |
| `git_org` | GitHub organization for ArgoCD access control | `"my-company-org"` | ✅ |
| `description` | Human-readable tenant description | `"Production workloads"` | ✅ |
| `cpu_quota` | CPU quota per namespace | `"20"` | ✅ |
| `memory_quota` | Memory quota per namespace | `"40Gi"` | ✅ |
| `storage_quota` | Storage quota per namespace | `"100Gi"` | ✅ |
| `gpu_quota` | GPU quota per namespace (0 = disabled) | `"2"` | ✅ |
| `environments` | List of environments to create | `["dev", "prod"]` | ✅ |

#### Discovery Settings

Automatic tenant discovery from application repositories:

```yaml
discovery:
  enabled: true
  scan_application_repos: true
  default_quotas:
    cpu_quota: "15"
    memory_quota: "30Gi"
    storage_quota: "75Gi"
    gpu_quota: "0"
```

## 🏗️ Infrastructure

### What Gets Created

For each tenant, the infrastructure module creates:

- **Namespaces**: One per environment (e.g., `tenant-dev`, `tenant-prod`)
- **Resource Quotas**: CPU, memory, storage, GPU, and object count limits
- **Network Policies**: Tenant isolation and controlled ingress/egress
- **RBAC**: Service accounts with limited permissions
- **ArgoCD Projects**: Tenant-specific GitOps projects
- **Limit Ranges**: Default and maximum resource limits

### Resource Quotas Applied

```yaml
# Per namespace quotas
requests.cpu: "20"
limits.cpu: "20"
requests.memory: "40Gi"
limits.memory: "40Gi"
requests.storage: "100Gi"
requests.nvidia.com/gpu: "2"    # If GPU quota > 0
limits.nvidia.com/gpu: "2"      # If GPU quota > 0

# Object count limits
pods: "50"
services: "20"
secrets: "50"
configmaps: "50"
persistentvolumeclaims: "10"
```

## 🔧 Management

### View Existing Tenants

```bash
# List all configured tenants
yq e '.tenants[].name' tenant-sources.yml

# View tenant details
yq e '.tenants[] | select(.name == "my-tenant")' tenant-sources.yml
```

### Verify Tenant Deployment

```bash
# Check namespaces
kubectl get namespaces | grep my-tenant

# Check resource quotas
kubectl get resourcequota -n my-tenant-dev

# Check ArgoCD projects
kubectl get appproject -n argocd | grep my-tenant
```

### Update Tenant Resources

1. Modify quotas in `tenant-sources.yml`
2. Run the onboarding script again:
   ```bash
   cd ../scripts
   ./onboard-tenants.sh
   ```

## 🚨 Important Notes

- **Tenant names** must be unique and use lowercase with hyphens
- **GPU quotas** require cluster with GPU nodes and nvidia device plugin
- **Git organizations** should match your actual GitHub organizations
- **Resource quotas** are enforced per namespace, not per tenant
- **Changes** to existing tenants require re-running the onboarding script

## 📚 Examples

### Basic Tenant (Small Startup)
```yaml
- name: "startup-co"
  git_org: "startup-co-github"
  description: "Small startup with basic needs"
  cpu_quota: "10"
  memory_quota: "20Gi"
  storage_quota: "50Gi"
  gpu_quota: "0"
  environments: ["dev", "prod"]
```

### AI/ML Tenant (GPU-enabled)
```yaml
- name: "ai-research"
  git_org: "ai-research-lab"
  description: "AI research team with GPU requirements"
  cpu_quota: "100"
  memory_quota: "200Gi"
  storage_quota: "500Gi"
  gpu_quota: "8"
  environments: ["dev", "staging", "prod"]
```

### Enterprise Tenant (High Resources)
```yaml
- name: "enterprise-corp"
  git_org: "enterprise-corp"
  description: "Large enterprise with multiple teams"
  cpu_quota: "200"
  memory_quota: "500Gi"
  storage_quota: "1Ti"
  gpu_quota: "4"
  environments: ["dev", "test", "staging", "prod"]
```

## 🔗 Related Documentation

- [Infrastructure README](./infrastructure/README.md) - Detailed Terraform documentation
- [Onboarding Script](../scripts/README.md) - Automation script documentation
- [Platform Architecture](../PLATFORM-ARCHITECTURE.md) - Overall platform design
