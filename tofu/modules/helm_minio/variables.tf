variable "namespace" {
  description = "Namespace where MinIO is deployed."
  type        = string
}

variable "release_name" {
  description = "Helm release name for MinIO."
  type        = string
}

variable "chart_version" {
  description = "MinIO chart version. Leave empty to use the repository default."
  type        = string
  default     = ""
}

variable "root_user" {
  description = "MinIO root user."
  type        = string
}

variable "root_password" {
  description = "MinIO root password."
  type        = string
  sensitive   = true
}

variable "timeout_seconds" {
  description = "Helm wait timeout for the MinIO deployment."
  type        = number
  default     = 900
}