# =============================================================================
# TENANT FACTORY - PROVIDER CONFIGURATION
# =============================================================================
# This file configures the Kubernetes and Helm providers for tenant module
# deployments. These providers are initialized by the parent configuration.
# =============================================================================

provider "kubernetes" {
  # Configuration is inherited from the parent module
  # Kubernetes config file or in-cluster service account
}

provider "helm" {
  # Configuration is inherited from the parent module
  kubernetes {
    # Use the same Kubernetes configuration as the kubernetes provider
  }
}
