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
    condition = local.using_existing_image_file_id || var.cloud_image_source_path != "" || (var.cloud_image_url != "" && var.cloud_image_file_name != "")
    error_message = "Set cloud_image_file_id, cloud_image_source_path, or set both cloud_image_url and cloud_image_file_name."
  }
}

variable "namespace_names" {
  description = "Namespaces to create once the cluster is reachable."
  type        = list(string)
}
