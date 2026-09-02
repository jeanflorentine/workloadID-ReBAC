variable "vm_name" {
  description = "Reference VM name reused across target wrappers."
  type        = string
}

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, including the trailing slash."
  type        = string
}

variable "proxmox_insecure" {
  description = "Whether to skip TLS verification for the Proxmox API."
  type        = bool
  default     = true
}

variable "proxmox_min_tls" {
  description = "Minimum TLS version for the Proxmox provider."
  type        = string
  default     = "1.2"
}

variable "proxmox_node_name" {
  description = "Target Proxmox node name for the reference VM."
  type        = string
}

variable "proxmox_vm_id" {
  description = "Explicit VM ID for the reference VM."
  type        = number
}

variable "image_datastore_id" {
  description = "Datastore that will hold the downloaded cloud image."
  type        = string
}

variable "vm_datastore_id" {
  description = "Datastore that will hold the VM disks and cloud-init drive."
  type        = string
}

variable "cloud_image_url" {
  description = "Pinned guest image URL for the reference VM."
  type        = string
  default     = ""
}

variable "cloud_image_source_path" {
  description = "Local guest image path for the reference VM."
  type        = string
  default     = ""
}

variable "cloud_image_file_name" {
  description = "Pinned guest image file name stored on Proxmox."
  type        = string
  default     = ""
}

variable "cloud_image_file_id" {
  description = "Existing Proxmox import file ID to reuse. If set, cloud image download is skipped."
  type        = string
  default     = ""
}

variable "vm_description" {
  description = "Human-readable description for the reference VM."
  type        = string
}

variable "vm_tags" {
  description = "Additional tags for the reference VM."
  type        = list(string)
  default     = []
}

variable "cpu_cores" {
  description = "Number of vCPU cores for the reference VM."
  type        = number
  default     = 4
}

variable "cpu_type" {
  description = "CPU type presented to the guest."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "memory_mb" {
  description = "Dedicated memory in MB for the reference VM."
  type        = number
  default     = 8192
}

variable "enable_ballooning" {
  description = "Whether to enable ballooning by setting floating memory equal to dedicated memory."
  type        = bool
  default     = false
}

variable "disk_size_gb" {
  description = "Boot disk size in GB for the reference VM."
  type        = number
  default     = 40
}

variable "network_bridge" {
  description = "Proxmox network bridge name."
  type        = string
  default     = "vmbr0"
}

variable "network_vlan_id" {
  description = "Optional VLAN ID for the reference VM. Use 0 for untagged."
  type        = number
  default     = 0
}

variable "vm_username" {
  description = "Cloud-init username for the reference VM."
  type        = string
  default     = "debian"
}

variable "vm_ssh_public_key" {
  description = "SSH public key content injected by cloud-init."
  type        = string
}

variable "vm_ipv4_address" {
  description = "IPv4 address used to reach the guest over SSH."
  type        = string
}

variable "vm_ipv4_cidr" {
  description = "IPv4 configuration passed to cloud-init, either dhcp or CIDR notation."
  type        = string
}

variable "vm_ipv4_gateway" {
  description = "IPv4 gateway for the guest when using a static address. Leave empty for DHCP."
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "DNS servers passed to cloud-init."
  type        = list(string)
  default     = []
}

variable "dns_search_domain" {
  description = "Optional DNS search domain passed to cloud-init."
  type        = string
  default     = ""
}

variable "vm_started" {
  description = "Whether the reference VM should be started after provisioning."
  type        = bool
  default     = true
}

variable "ssh_private_key_path" {
  description = "Private key path used by terraform_data remote-exec during k3s bootstrap."
  type        = string
}

variable "ssh_port" {
  description = "SSH port used to reach the guest."
  type        = number
  default     = 22
}

variable "k3s_channel" {
  description = "Installation channel for k3s."
  type        = string
  default     = "stable"
}

variable "install_qemu_guest_agent" {
  description = "Whether the bootstrap should install and start qemu-guest-agent inside the guest."
  type        = bool
  default     = true
}

locals {
  using_existing_image_file_id = var.cloud_image_file_id != ""
}

check "cloud_image_source" {
  assert {
    condition     = local.using_existing_image_file_id || var.cloud_image_source_path != "" || (var.cloud_image_url != "" && var.cloud_image_file_name != "")
    error_message = "Set cloud_image_file_id, cloud_image_source_path, or set both cloud_image_url and cloud_image_file_name."
  }
}

variable "namespace_names" {
  description = "Namespaces to create once the cluster is reachable."
  type        = list(string)
}

variable "kubeconfig_path" {
  description = "Path to the local kubeconfig used by Kubernetes and Helm providers."
  type        = string
}

variable "enable_keycloak" {
  description = "Whether to deploy Keycloak through Helm."
  type        = bool
  default     = false
}

variable "keycloak_namespace" {
  description = "Namespace where Keycloak is deployed."
  type        = string
  default     = "identity"
}

variable "keycloak_release_name" {
  description = "Helm release name for Keycloak."
  type        = string
  default     = "keycloak"
}

variable "keycloak_chart_version" {
  description = "Bitnami Keycloak chart version."
  type        = string
  default     = "24.4.13"
}

variable "keycloak_admin_username" {
  description = "Initial Keycloak admin user."
  type        = string
  default     = "admin"
}

variable "keycloak_admin_password" {
  description = "Initial Keycloak admin password."
  type        = string
  sensitive   = true
}

variable "keycloak_timeout_seconds" {
  description = "Helm wait timeout for Keycloak installation."
  type        = number
  default     = 900
}

variable "enable_spire" {
  description = "Whether to deploy SPIRE through Helm."
  type        = bool
  default     = false
}

variable "spire_namespace" {
  description = "Namespace where SPIRE is deployed."
  type        = string
  default     = "identity"
}

variable "spire_release_name" {
  description = "Helm release name for SPIRE."
  type        = string
  default     = "spire"
}

variable "spire_chart_version" {
  description = "SPIRE Helm chart version. Leave empty to use the repository default."
  type        = string
  default     = ""
}

variable "spire_trust_domain" {
  description = "SPIRE trust domain for the lab cluster."
  type        = string
  default     = "orange.lab"
}

variable "spire_timeout_seconds" {
  description = "Helm wait timeout for SPIRE installation."
  type        = number
  default     = 900
}

variable "enable_openbao" {
  description = "Whether to deploy OpenBao through Helm."
  type        = bool
  default     = false
}

variable "openbao_namespace" {
  description = "Namespace where OpenBao is deployed."
  type        = string
  default     = "secrets"
}

variable "openbao_release_name" {
  description = "Helm release name for OpenBao."
  type        = string
  default     = "openbao"
}

variable "openbao_chart_version" {
  description = "OpenBao Helm chart version. Leave empty to use the repository default."
  type        = string
  default     = ""
}

variable "openbao_root_token" {
  description = "Development root token injected into the OpenBao dev server."
  type        = string
  sensitive   = true
}

variable "openbao_timeout_seconds" {
  description = "Helm wait timeout for OpenBao installation."
  type        = number
  default     = 900
}

variable "enable_minio" {
  description = "Whether to deploy MinIO through Helm."
  type        = bool
  default     = false
}

variable "minio_namespace" {
  description = "Namespace where MinIO is deployed."
  type        = string
  default     = "storage"
}

variable "minio_release_name" {
  description = "Helm release name for MinIO."
  type        = string
  default     = "minio"
}

variable "minio_chart_version" {
  description = "MinIO Helm chart version. Leave empty to use the repository default."
  type        = string
  default     = ""
}

variable "minio_root_user" {
  description = "MinIO root user for the lab deployment."
  type        = string
  default     = "minioadmin"
}

variable "minio_root_password" {
  description = "MinIO root password for the lab deployment."
  type        = string
  sensitive   = true
}

variable "minio_timeout_seconds" {
  description = "Helm wait timeout for MinIO installation."
  type        = number
  default     = 900
}

variable "enable_openfga" {
  description = "Whether to deploy OpenFGA through Helm."
  type        = bool
  default     = false
}

variable "openfga_namespace" {
  description = "Namespace where OpenFGA is deployed."
  type        = string
  default     = "authorization"
}

variable "openfga_release_name" {
  description = "Helm release name for OpenFGA."
  type        = string
  default     = "openfga"
}

variable "openfga_chart_version" {
  description = "OpenFGA Helm chart version. Leave empty to use the repository default."
  type        = string
  default     = ""
}

variable "openfga_datastore_engine" {
  description = "OpenFGA datastore engine used for the lab deployment."
  type        = string
  default     = "memory"
}

variable "openfga_log_level" {
  description = "OpenFGA log verbosity."
  type        = string
  default     = "info"
}

variable "openfga_timeout_seconds" {
  description = "Helm wait timeout for OpenFGA installation."
  type        = number
  default     = 900
}
