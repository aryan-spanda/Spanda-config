output "tenant_namespaces" {
  description = "The names of the namespaces created for the tenant."
  value       = module.tenant.tenant_namespaces
}

output "tenant_name" {
  description = "The name of the tenant."
  value       = module.tenant.tenant_name
}

output "tenant_git_org" {
  description = "The GitHub organization for the tenant."
  value       = module.tenant.tenant_git_org
}

output "argocd_project_name" {
  description = "The name of the ArgoCD project created for the tenant."
  value       = module.tenant.argocd_project_name
}

output "service_accounts" {
  description = "The service accounts created for tenant automation."
  value       = module.tenant.service_accounts
}

output "resource_quotas" {
  description = "The resource quotas applied to tenant namespaces."
  value       = module.tenant.resource_quotas
}

output "namespace_details" {
  description = "Detailed information about created namespaces."
  value       = module.tenant.namespace_details
}
