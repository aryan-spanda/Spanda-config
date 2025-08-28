# Tenant Infrastructure

This directory contains the Terraform infrastructure code for provisioning isolated tenant environments within the Spanda AI Platform. It provides complete multi-tenant isolation with proper governance, resource quotas, and ArgoCD project isolation.

## 🏗️ Architecture

```
infrastructure/
├── main.tf                    # Entry point - calls tenant-factory module
├── variables.tf               # Input variables for tenant provisioning
├── outputs.tf                 # Outputs from tenant creation
├── README.md                  # This documentation
└── tenant-factory/            # Reusable tenant factory module
    ├── main.tf               # Core tenant resources implementation
    ├── variables.tf          # Module input variables
    ├── outputs.tf            # Module outputs
    └── README.md             # Module-specific documentation
```

## ✨ Features

- ✅ **Namespace Isolation**: Creates dedicated namespaces per tenant per environment
- ✅ **Resource Quotas**: Enforces CPU, memory, storage, GPU, and object count limits
- ✅ **Network Policies**: Implements network-level tenant isolation
- ✅ **RBAC Controls**: Creates service accounts with limited permissions
- ✅ **ArgoCD Integration**: Creates tenant-specific ArgoCD projects
- ✅ **Limit Ranges**: Sets default and maximum resource limits including GPU limits
- ✅ **GPU Support**: Optional GPU quota allocation for AI/ML workloads

## 🚀 Usage

### Automated (Recommended)

Use the tenant onboarding script:

```bash
# From the config-repo/scripts directory
./onboard-tenants.sh
```

This script:
1. Reads tenant configurations from `../tenants/tenant-sources.yml`
2. Creates Terraform variable files for each tenant
3. Runs `terraform apply` to provision infrastructure
4. Handles multiple tenants automatically

### Manual

```bash
# Navigate to infrastructure directory
cd tenants/infrastructure

# Initialize Terraform
terraform init

# Create tenant variables file
cat > tenant.tfvars << EOF
tenant_name    = "my-tenant"
tenant_git_org = "my-github-org"
environments   = ["dev", "staging", "production"]
cpu_quota      = "30"
memory_quota   = "60Gi"
storage_quota  = "150Gi"
gpu_quota      = "2"
EOF

# Apply configuration
terraform apply -var-file="tenant.tfvars"
```

## 📋 Input Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|:--------:|
| `tenant_name` | Unique tenant identifier (lowercase, hyphenated) | `string` | - | ✅ |
| `tenant_git_org` | GitHub organization for ArgoCD restrictions | `string` | - | ✅ |
| `environments` | List of environments to create | `list(string)` | `["dev", "staging", "production"]` | ❌ |
| `cpu_quota` | CPU quota per namespace | `string` | `"10"` | ❌ |
| `memory_quota` | Memory quota per namespace | `string` | `"20Gi"` | ❌ |
| `storage_quota` | Storage quota per namespace | `string` | `"50Gi"` | ❌ |
| `gpu_quota` | GPU quota per namespace (set "0" to disable) | `string` | `"0"` | ❌ |
| `pod_quota` | Pod count limit per namespace | `string` | `"50"` | ❌ |
| `service_quota` | Service count limit per namespace | `string` | `"20"` | ❌ |

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `tenant_namespaces` | List of created namespace names |
| `tenant_name` | The tenant identifier |
| `tenant_git_org` | The GitHub organization |
| `argocd_project_name` | ArgoCD project name for the tenant |
| `service_accounts` | Service accounts created for automation |
| `resource_quotas` | Applied resource quotas |
| `namespace_details` | Detailed namespace information |

## 🔒 Security Model

### Namespace Isolation
- Each tenant can only access their own namespaces
- Platform services are accessible to all tenants
- External internet access allowed for HTTPS/HTTP
- DNS resolution permitted to kube-system

### ArgoCD Isolation
- Each tenant gets a dedicated ArgoCD project
- Source repositories restricted to tenant's GitHub organization
- Deployments restricted to tenant's namespaces only
- No cluster-level resource permissions

### Network Policies
- Ingress allowed from same tenant and platform namespaces
- Egress allowed to same tenant, platform services, and internet
- Isolation between different tenants

### Resource Governance
- CPU and memory quotas prevent resource exhaustion
- Pod and service limits prevent cluster abuse
- Storage quotas control persistent volume usage
- Container limits enforce responsible resource usage

## 🏭 What Gets Created

For a tenant named `my-tenant` with environments `["dev", "staging", "production"]`:

### Namespaces
- `my-tenant-dev`
- `my-tenant-staging`
- `my-tenant-production`

### Per Namespace
- **Resource Quota**: CPU, memory, storage, and object limits
- **Network Policy**: Tenant isolation rules
- **Service Account**: `my-tenant-automation`
- **RBAC Role & Binding**: Full access within namespace
- **Limit Range**: Default and maximum resource limits

### Cluster Level
- **ArgoCD Project**: `my-tenant` (restricts source repos and destinations)

## 🔧 Integration Points

This infrastructure integrates with:

1. **Tenant Configuration**: `../tenant-sources.yml`
2. **Onboarding Script**: `../scripts/onboard-tenants.sh`
3. **Application Sources**: `../application-sources.yml`
4. **ArgoCD Applications**: Generated by `generate-argocd-applications-simple.sh`

## 📋 Prerequisites

- Kubernetes cluster with kubectl access
- Terraform >= 1.0
- ArgoCD installed in `argocd` namespace
- Proper RBAC permissions for namespace and resource creation

## 🛠️ Troubleshooting

### Common Issues

**Terraform Init Fails**
```bash
# Check if in correct directory
pwd  # Should be in config-repo/tenants/infrastructure

# Ensure kubectl access
kubectl get nodes
```

**Resource Already Exists**
```bash
# Check existing tenants
kubectl get namespaces -l spanda.ai/managed-by=tenant-factory

# Check ArgoCD projects
kubectl get appprojects -n argocd
```

**Permission Denied**
```bash
# Check kubectl permissions
kubectl auth can-i create namespaces
kubectl auth can-i create appprojects -n argocd
```

### Verification Commands

```bash
# List tenant namespaces
kubectl get namespaces -l spanda.ai/managed-by=tenant-factory

# Check resource quotas
kubectl get resourcequotas --all-namespaces

# Verify ArgoCD projects
kubectl get appprojects -n argocd

# Check network policies
kubectl get networkpolicies --all-namespaces
```

## 📚 Examples

### Basic Tenant
```hcl
tenant_name    = "startup-xyz"
tenant_git_org = "startup-xyz-org"
# Uses all defaults
```

### Enterprise Tenant
```hcl
tenant_name    = "enterprise-corp"
tenant_git_org = "enterprise-corp"
environments   = ["dev", "test", "staging", "prod"]
cpu_quota      = "200"
memory_quota   = "500Gi"
storage_quota  = "1Ti"
gpu_quota      = "8"
pod_quota      = "200"
service_quota  = "100"
```

## 🔄 Maintenance

### Adding New Tenant
1. Update `../tenant-sources.yml`
2. Run `../scripts/onboard-tenants.sh`

### Updating Existing Tenant
1. Modify tenant configuration in `tenant-sources.yml`
2. Re-run onboarding script (it will update existing resources)

### Removing Tenant
```bash
# Manual cleanup required
kubectl delete namespace tenant-name-dev tenant-name-staging tenant-name-production
kubectl delete appproject tenant-name -n argocd
```

## 📄 Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| kubernetes provider | ~> 2.23 |

## 🤝 Contributing

When modifying tenant infrastructure:

1. Test changes with a development tenant first
2. Update documentation if adding new features
3. Ensure backward compatibility with existing tenants
4. Test the onboarding script after changes
