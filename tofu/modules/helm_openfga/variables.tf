variable "namespace" {
  description = "Namespace where OpenFGA is deployed."
  type        = string
}

variable "release_name" {
  description = "Helm release name for OpenFGA."
  type        = string
}

variable "chart_version" {
  description = "OpenFGA chart version. Leave empty to use the repository default."
  type        = string
  default     = ""
}

variable "datastore_engine" {
  description = "OpenFGA datastore engine."
  type        = string
}

variable "log_level" {
  description = "OpenFGA log verbosity."
  type        = string
}

variable "timeout_seconds" {
  description = "Helm wait timeout for the OpenFGA deployment."
  type        = number
  default     = 900
}