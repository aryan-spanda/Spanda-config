variable "tenant_name" {
  description = "A unique name for the tenant (e.g., 'acme-corp'). Should be lowercase and hyphenated."
  type        = string
}

variable "tenant_git_org" {
  description = "The GitHub organization name for the tenant (e.g., 'acme-corp-org'). Used to restrict ArgoCD."
  type        = string
}

variable "environments" {
  description = "A list of environments to create for the tenant."
  type        = list(string)
  default     = ["dev", "staging", "production"]
}

variable "cpu_quota" {
  description = "The total CPU request/limit quota for each tenant namespace (e.g., '20')."
  type        = string
  default     = "10"
}

variable "memory_quota" {
  description = "The total memory request/limit quota for each tenant namespace (e.g., '40Gi')."
  type        = string
  default     = "20Gi"
}

variable "storage_quota" {
  description = "The total persistent volume claims quota for each tenant namespace (e.g., '100Gi')."
  type        = string
  default     = "50Gi"
}

variable "gpu_quota" {
  description = "The total GPU quota for each tenant namespace (e.g., '2'). Set to '0' to disable GPU access."
  type        = string
  default     = "0"
}

variable "pod_quota" {
  description = "The maximum number of pods allowed per tenant namespace."
  type        = string
  default     = "50"
}

variable "service_quota" {
  description = "The maximum number of services allowed per tenant namespace."
  type        = string
  default     = "20"
}

variable "modules" {
  description = "A list of modules to deploy for the tenant."
  type        = any
  default     = []
}
