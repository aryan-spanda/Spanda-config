# Platform Modules Integration Template
# This file is provided by the platform team

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

# Variables for module configuration (client customizes these)
variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "CHANGE_ME"  # Client must update
}

variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "CHANGE_ME-prod"  # Client must update
}

variable "image_name" {
  description = "Docker image name"
  type        = string
  default     = "CHANGE_ME/CHANGE_ME"  # Client must update
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "platform_repo_path" {
  description = "Path to the platform deployment repository"
  type        = string
  default     = "https://github.com/your-org/spandaai-platform-deployment//bare-metal/modules"
}

# Load platform module configuration from platform-modules.yaml
locals {
  # Read platform module config (ArgoCD will inject these as env vars)
  vpc_enabled = var.enable_vpc_module
  lb_enabled = var.enable_lb_module
  firewall_enabled = var.enable_firewall_module
  external_lb_enabled = var.enable_external_lb_module
}

# Conditional module deployments based on platform-modules.yaml

# VPC Networking Module
module "vpc_networking" {
  count  = local.vpc_enabled ? 1 : 0
  source = "${var.platform_repo_path}/net-vpc-baremetal"
  
  vpc_cidr = var.vpc_cidr
  
  tags = {
    Application = var.app_name
    Environment = "production"
    ManagedBy   = "terraform-gitops"
  }
}

# Load Balancer Module
module "load_balancer" {
  count  = local.lb_enabled ? 1 : 0
  source = "${var.platform_repo_path}/net-lb-baremetal"
  
  depends_on = [module.vpc_networking]
  
  lb_name = "${var.app_name}-lb"
  
  tags = {
    Application = var.app_name
    Environment = "production"
    ManagedBy   = "terraform-gitops"
  }
}

# External Application Load Balancer
module "external_app_lb" {
  count  = local.external_lb_enabled ? 1 : 0
  source = "${var.platform_repo_path}/net-lb-app-external-baremetal"
  
  depends_on = [module.load_balancer]
  
  app_name  = var.app_name
  namespace = var.namespace
  
  external_ip_range = var.lb_external_ip_range
  
  tags = {
    Application = var.app_name
    Environment = "production"
    ManagedBy   = "terraform-gitops"
  }
}

# Firewall Module
module "firewall" {
  count  = local.firewall_enabled ? 1 : 0
  source = "${var.platform_repo_path}/net-firewall-baremetal"
  
  depends_on = [module.vpc_networking]
  
  allowed_ports = var.allowed_ports
  app_name     = var.app_name
  
  tags = {
    Application = var.app_name
    Environment = "production"
    ManagedBy   = "terraform-gitops"
  }
}

# Additional variables with defaults
variable "enable_vpc_module" {
  type    = bool
  default = true
}

variable "enable_lb_module" {
  type    = bool
  default = true
}

variable "enable_firewall_module" {
  type    = bool
  default = true
}

variable "enable_external_lb_module" {
  type    = bool
  default = true
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "lb_external_ip_range" {
  type    = string
  default = "192.168.1.100-192.168.1.110"
}

variable "allowed_ports" {
  type    = list(number)
  default = [80, 443]
}

# Outputs
output "vpc_id" {
  description = "VPC ID from networking module"
  value       = length(module.vpc_networking) > 0 ? module.vpc_networking[0].vpc_id : null
}

output "load_balancer_ip" {
  description = "External load balancer IP"
  value       = length(module.external_app_lb) > 0 ? module.external_app_lb[0].load_balancer_ip : null
}

output "namespace" {
  description = "Kubernetes namespace"
  value       = var.namespace
}
