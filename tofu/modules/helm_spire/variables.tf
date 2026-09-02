variable "namespace" {
  description = "Namespace where SPIRE is deployed."
  type        = string
}

variable "release_name" {
  description = "Helm release name for SPIRE."
  type        = string
}

variable "chart_version" {
  description = "SPIRE chart version. Leave empty to use the repository default."
  type        = string
  default     = ""
}

variable "trust_domain" {
  description = "SPIRE trust domain for the cluster."
  type        = string
}

variable "timeout_seconds" {
  description = "Helm wait timeout for the SPIRE deployment."
  type        = number
  default     = 900
}