output "tenant_namespaces" {
  description = "The names of the namespaces created for the tenant."
  value       = [for ns in kubernetes_namespace.tenant_namespace : ns.metadata[0].name]
}

output "tenant_name" {
  description = "The name of the tenant."
  value       = var.tenant_name
}

output "tenant_git_org" {
  description = "The GitHub organization for the tenant."
  value       = var.tenant_git_org
}

output "argocd_project_name" {
  description = "The name of the ArgoCD project created for the tenant."
  value       = var.tenant_name
}

output "service_accounts" {
  description = "The service accounts created for tenant automation."
  value = {
    for env in var.environments : env => {
      name      = kubernetes_service_account.tenant_automation_sa[env].metadata[0].name
      namespace = kubernetes_service_account.tenant_automation_sa[env].metadata[0].namespace
    }
  }
}

output "resource_quotas" {
  description = "The resource quotas applied to tenant namespaces."
  value = {
    cpu_quota     = var.cpu_quota
    memory_quota  = var.memory_quota
    storage_quota = var.storage_quota
    pod_quota     = var.pod_quota
    service_quota = var.service_quota
  }
}

output "namespace_details" {
  description = "Detailed information about created namespaces."
  value = {
    for env in var.environments : env => {
      name      = kubernetes_namespace.tenant_namespace[env].metadata[0].name
      labels    = kubernetes_namespace.tenant_namespace[env].metadata[0].labels
      annotations = kubernetes_namespace.tenant_namespace[env].metadata[0].annotations
    }
  }
}
