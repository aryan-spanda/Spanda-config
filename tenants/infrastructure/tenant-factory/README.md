# Tenant Factory Module

This Terraform module creates isolated tenant environments within the Spanda AI Platform. It provides complete multi-tenant isolation with resource quotas, network policies, RBAC controls, and ArgoCD project isolation.

## Features

- ✅ **Namespace Isolation**: Creates dedicated namespaces per tenant per environment
- ✅ **Resource Quotas**: Enforces CPU, memory, storage, and object count limits
- ✅ **Network Policies**: Implements network-level tenant isolation
- ✅ **RBAC Controls**: Creates service accounts with limited permissions
- ✅ **ArgoCD Integration**: Creates tenant-specific ArgoCD projects
- ✅ **Limit Ranges**: Sets default and maximum resource limits

## Usage

```hcl
module "tenant_acme" {
  source = "./tenant-factory"

  tenant_name    = "acme-corp"
  tenant_git_org = "acme-corp-github"
  environments   = ["dev", "staging", "prod"]
  cpu_quota      = "50"
  memory_quota   = "100Gi"
  storage_quota  = "200Gi"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| tenant_name | A unique name for the tenant | `string` | n/a | yes |
| tenant_git_org | The GitHub organization name for the tenant | `string` | n/a | yes |
| environments | A list of environments to create | `list(string)` | `["dev", "staging", "prod"]` | no |
| cpu_quota | CPU quota per namespace | `string` | `"10"` | no |
| memory_quota | Memory quota per namespace | `string` | `"20Gi"` | no |
| storage_quota | Storage quota per namespace | `string` | `"50Gi"` | no |
| pod_quota | Pod count quota per namespace | `string` | `"50"` | no |
| service_quota | Service count quota per namespace | `string` | `"20"` | no |

## Outputs

| Name | Description |
|------|-------------|
| tenant_namespaces | The names of the namespaces created for the tenant |
| tenant_name | The name of the tenant |
| tenant_git_org | The GitHub organization for the tenant |
| argocd_project_name | The name of the ArgoCD project created for the tenant |
| service_accounts | The service accounts created for tenant automation |
| resource_quotas | The resource quotas applied to tenant namespaces |
| namespace_details | Detailed information about created namespaces |

## Security Model

### Network Isolation
- Each tenant can only access their own namespaces
- Platform services are accessible to all tenants
- External internet access is allowed for HTTPS/HTTP
- DNS resolution is permitted

### ArgoCD Isolation
- Each tenant gets their own ArgoCD project
- Source repositories are restricted to tenant's GitHub organization
- Deployments are restricted to tenant's namespaces only
- No cluster-level resource permissions

### Resource Limits
- CPU and memory quotas prevent resource exhaustion
- Pod and service count limits prevent cluster abuse
- Storage quotas control persistent volume usage
- Container limits enforce responsible resource usage

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| kubernetes | ~> 2.23 |

## Providers

| Name | Version |
|------|---------|
| kubernetes | ~> 2.23 |
