variable "namespace" {
  description = "Kubernetes namespace where Keycloak will be deployed."
  type        = string
}

variable "release_name" {
  description = "Helm release name for Keycloak."
  type        = string
  default     = "keycloak"
}

variable "chart_version" {
  description = "Bitnami Keycloak chart version."
  type        = string
  default     = "24.4.13"
}

variable "admin_username" {
  description = "Initial Keycloak admin username."
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Initial Keycloak admin password."
  type        = string
  sensitive   = true
}

variable "timeout_seconds" {
  description = "Helm wait timeout in seconds."
  type        = number
  default     = 900
}