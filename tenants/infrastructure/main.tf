# =============================================================================
# SPANDA AI PLATFORM - TENANT INFRASTRUCTURE PROVISIONING
# =============================================================================
# This configuration provisions tenant infrastructure based on the tenant
# definitions. It's designed to work with the tenant onboarding script.
# =============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Configure the Kubernetes provider to use local cluster
provider "kubernetes" {
  host         = "https://127.0.0.1:42361"
  config_path  = "~/.kube/config"
  config_context = "kind-spanda-cluster"
}

# Configure the Helm provider to use local cluster
provider "helm" {
  kubernetes {
    host        = "https://127.0.0.1:42361"
    config_path = "~/.kube/config"
    config_context = "kind-spanda-cluster"
  }
}

# =============================================================================
# TENANT FACTORY MODULE INSTANTIATION
# =============================================================================
# This module creates all the tenant infrastructure including namespaces,
# quotas, network policies, RBAC, and ArgoCD projects.

module "tenant" {
  source = "./tenant-factory"

  tenant_name    = var.tenant_name
  tenant_git_org = var.tenant_git_org
  environments   = var.environments
  cpu_quota      = var.cpu_quota
  memory_quota   = var.memory_quota
  storage_quota  = var.storage_quota
  gpu_quota      = var.gpu_quota
  pod_quota      = var.pod_quota
  service_quota  = var.service_quota
  modules        = var.modules
}
