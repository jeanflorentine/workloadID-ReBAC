variable "namespace" {
  description = "Namespace where OpenBao is deployed."
  type        = string
}

variable "release_name" {
  description = "Helm release name for OpenBao."
  type        = string
}

variable "chart_version" {
  description = "OpenBao chart version. Leave empty to use the repository default."
  type        = string
  default     = ""
}

variable "root_token" {
  description = "Development root token injected into OpenBao."
  type        = string
  sensitive   = true
}

variable "timeout_seconds" {
  description = "Helm wait timeout for the OpenBao deployment."
  type        = number
  default     = 900
}