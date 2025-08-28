# =============================================================================
# SPANDA AI PLATFORM - TENANT FACTORY MODULE
# =============================================================================
# This module creates isolated tenant environments with proper governance,
# resource quotas, and ArgoCD project isolation for multi-tenant deployments.
# =============================================================================

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# =============================================================================
# 1. CREATE DEDICATED NAMESPACES FOR EACH ENVIRONMENT
# =============================================================================
resource "kubernetes_namespace" "tenant_namespace" {
  for_each = toset(var.environments)

  metadata {
    name = "${var.tenant_name}-${each.key}"
    labels = {
      "spanda.ai/tenant"        = var.tenant_name
      "spanda.ai/environment"   = each.key
      "spanda.ai/managed-by"    = "tenant-factory"
      "app.kubernetes.io/part-of" = "spanda-platform"
    }
    annotations = {
      "spanda.ai/created-by" = "tenant-factory"
      "spanda.ai/tenant-org" = var.tenant_git_org
    }
  }
}

# =============================================================================
# 2. CREATE RESOURCE QUOTAS FOR EACH NAMESPACE
# =============================================================================
resource "kubernetes_resource_quota" "tenant_quota" {
  for_each = toset(var.environments)

  metadata {
    name      = "${var.tenant_name}-quota"
    namespace = kubernetes_namespace.tenant_namespace[each.key].metadata[0].name
  }

  spec {
    hard = {
      # CPU and Memory Quotas
      "requests.cpu"    = var.cpu_quota
      "limits.cpu"      = var.cpu_quota
      "requests.memory" = var.memory_quota
      "limits.memory"   = var.memory_quota
      
      # Storage Quotas
      "requests.storage"                    = var.storage_quota
      "persistentvolumeclaims"             = "10"
      
      # GPU Quotas (only add if GPU quota is greater than 0)
      "requests.nvidia.com/gpu"            = var.gpu_quota != "0" ? var.gpu_quota : null
      "limits.nvidia.com/gpu"              = var.gpu_quota != "0" ? var.gpu_quota : null
      
      # Object Count Quotas
      "pods"                               = var.pod_quota
      "services"                           = var.service_quota
      "secrets"                            = "50"
      "configmaps"                         = "50"
      "replicationcontrollers"             = "20"
      "services.loadbalancers"             = "5"
      "services.nodeports"                 = "10"
      
      # Workload Quotas
      "count/deployments.apps"             = "20"
      "count/statefulsets.apps"            = "10"
      "count/jobs.batch"                   = "20"
      "count/cronjobs.batch"               = "10"
    }
  }
}

# =============================================================================
# 3. CREATE NETWORK POLICIES FOR TENANT ISOLATION
# =============================================================================
resource "kubernetes_network_policy" "tenant_isolation" {
  for_each = toset(var.environments)

  metadata {
    name      = "${var.tenant_name}-isolation"
    namespace = kubernetes_namespace.tenant_namespace[each.key].metadata[0].name
  }

  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    # Allow ingress from same tenant namespaces and platform namespaces
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "spanda.ai/tenant" = var.tenant_name
          }
        }
      }
      
      from {
        namespace_selector {
          match_labels = {
            "spanda.ai/platform" = "true"
          }
        }
      }
      
      # Allow ingress from ingress controllers
      from {
        namespace_selector {
          match_labels = {
            "name" = "ingress-nginx"
          }
        }
      }
    }
    
    # Allow egress to same tenant namespaces
    egress {
      to {
        namespace_selector {
          match_labels = {
            "spanda.ai/tenant" = var.tenant_name
          }
        }
      }
    }
    
    # Allow egress to platform services
    egress {
      to {
        namespace_selector {
          match_labels = {
            "spanda.ai/platform" = "true"
          }
        }
      }
    }
    
    # Allow DNS resolution to kube-system
    egress {
      to {
        namespace_selector {
          match_labels = {
            "name" = "kube-system"
          }
        }
      }
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
    
    # Allow HTTPS egress to external services
    egress {
      # Allow all egress for HTTPS
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
    
    # Allow HTTP egress to external services
    egress {
      # Allow all egress for HTTP
      ports {
        protocol = "TCP"
        port     = "80"
      }
    }
  }
}

# =============================================================================
# 4. CREATE DEDICATED SERVICE ACCOUNTS FOR TENANT AUTOMATION
# =============================================================================
resource "kubernetes_service_account" "tenant_automation_sa" {
  for_each = toset(var.environments)
  
  metadata {
    name      = "${var.tenant_name}-automation"
    namespace = kubernetes_namespace.tenant_namespace[each.key].metadata[0].name
    labels = {
      "spanda.ai/tenant"      = var.tenant_name
      "spanda.ai/environment" = each.key
      "spanda.ai/role"        = "automation"
    }
  }
}

# =============================================================================
# 5. CREATE RBAC FOR TENANT SERVICE ACCOUNTS
# =============================================================================
resource "kubernetes_role" "tenant_automation_role" {
  for_each = toset(var.environments)
  
  metadata {
    name      = "${var.tenant_name}-automation"
    namespace = kubernetes_namespace.tenant_namespace[each.key].metadata[0].name
  }
  
  # Allow full access within tenant namespace
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "tenant_automation_binding" {
  for_each = toset(var.environments)
  
  metadata {
    name      = "${var.tenant_name}-automation"
    namespace = kubernetes_namespace.tenant_namespace[each.key].metadata[0].name
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.tenant_automation_role[each.key].metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.tenant_automation_sa[each.key].metadata[0].name
    namespace = kubernetes_namespace.tenant_namespace[each.key].metadata[0].name
  }
}

# =============================================================================
# 6. CREATE TENANT-SPECIFIC ARGOCD APPPROJECT
# =============================================================================
resource "kubernetes_manifest" "tenant_app_project" {
  manifest = {
    "apiVersion" = "argoproj.io/v1alpha1"
    "kind"       = "AppProject"
    "metadata" = {
      "name"      = var.tenant_name
      "namespace" = "argocd"
      "labels" = {
        "spanda.ai/tenant"     = var.tenant_name
        "spanda.ai/managed-by" = "tenant-factory"
      }
    }
    "spec" = {
      "description" = "ArgoCD Project for tenant: ${var.tenant_name}"

      # Restrict source repositories to the tenant's own Git organization
      "sourceRepos" = [
        "https://github.com/${var.tenant_git_org}/*"
      ]

      # Restrict deployments to the tenant's own namespaces
      "destinations" = [
        for env in var.environments : {
          "namespace" = "${var.tenant_name}-${env}"
          "server"    = "https://kubernetes.default.svc"
        }
      ]

      # Whitelist the resources that the tenant is allowed to create
      "namespaceResourceWhitelist" = [
        # Core resources
        { "group" = "", "kind" = "Service" },
        { "group" = "", "kind" = "ConfigMap" },
        { "group" = "", "kind" = "Secret" },
        { "group" = "", "kind" = "ServiceAccount" },
        { "group" = "", "kind" = "PersistentVolumeClaim" },
        
        # Workload resources
        { "group" = "apps", "kind" = "Deployment" },
        { "group" = "apps", "kind" = "ReplicaSet" },
        { "group" = "apps", "kind" = "StatefulSet" },
        { "group" = "apps", "kind" = "DaemonSet" },
        
        # Batch resources
        { "group" = "batch", "kind" = "Job" },
        { "group" = "batch", "kind" = "CronJob" },
        
        # Networking resources
        { "group" = "networking.k8s.io", "kind" = "Ingress" },
        { "group" = "networking.k8s.io", "kind" = "NetworkPolicy" },
        
        # Scaling resources
        { "group" = "autoscaling", "kind" = "HorizontalPodAutoscaler" },
        
        # Monitoring resources
        { "group" = "monitoring.coreos.com", "kind" = "ServiceMonitor" },
        { "group" = "monitoring.coreos.com", "kind" = "PodMonitor" },
        
        # Custom resources (can be restricted further)
        { "group" = "*", "kind" = "CustomResourceDefinition" }
      ]
      
      # No cluster-level resources for tenants
      "clusterResourceWhitelist" = []
      
      # RBAC configuration
      "roles" = [
        {
          "name" = "admin"
          "description" = "Admin access for tenant ${var.tenant_name}"
          "policies" = [
            "p, proj:${var.tenant_name}:admin, applications, *, ${var.tenant_name}/*, allow",
            "p, proj:${var.tenant_name}:admin, repositories, *, *, allow",
            "p, proj:${var.tenant_name}:admin, clusters, get, *, allow"
          ]
          "groups" = []
        }
      ]
    }
  }
}

# =============================================================================
# 7. CREATE LIMIT RANGES FOR RESOURCE GOVERNANCE
# =============================================================================
resource "kubernetes_limit_range" "tenant_limit_range" {
  for_each = toset(var.environments)
  
  metadata {
    name      = "${var.tenant_name}-limits"
    namespace = kubernetes_namespace.tenant_namespace[each.key].metadata[0].name
  }
  
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
      max = merge(
        {
          cpu    = "2"
          memory = "4Gi"
        },
        var.gpu_quota != "0" ? {
          "nvidia.com/gpu" = "1"
        } : {}
      )
      min = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
    
    limit {
      type = "Pod"
      max = merge(
        {
          cpu    = "4"
          memory = "8Gi"
        },
        var.gpu_quota != "0" ? {
          "nvidia.com/gpu" = var.gpu_quota
        } : {}
      )
    }
    
    limit {
      type = "PersistentVolumeClaim"
      min = {
        storage = "1Gi"
      }
      max = {
        storage = "100Gi"
      }
    }
  }
}
