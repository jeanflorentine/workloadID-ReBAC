variable "vm_name" {
  description = "Name of the lab VM on Proxmox."
  type        = string
}

variable "proxmox_node_name" {
  description = "Target Proxmox node name."
  type        = string
}

variable "proxmox_vm_id" {
  description = "Explicit Proxmox VM ID."
  type        = number
}

variable "image_datastore_id" {
  description = "Datastore used for the uploaded or downloaded cloud image."
  type        = string
}

variable "vm_datastore_id" {
  description = "Datastore used for the VM disks."
  type        = string
}

variable "cloud_image_url" {
  description = "Pinned cloud image URL."
  type        = string
  default     = ""
}

variable "cloud_image_source_path" {
  description = "Local cloud image path to upload into Proxmox before import."
  type        = string
  default     = ""
}

variable "cloud_image_file_name" {
  description = "Pinned cloud image file name stored on Proxmox."
  type        = string
  default     = ""
}

variable "cloud_image_file_id" {
  description = "Existing Proxmox import file ID to reuse, for example local:import/debian-12-genericcloud-amd64.qcow2. If set, upload or URL download is skipped."
  type        = string
  default     = ""
}

variable "vm_description" {
  description = "Human-readable VM description."
  type        = string
}

variable "vm_tags" {
  description = "Additional tags for the Proxmox VM."
  type        = list(string)
}

variable "cpu_cores" {
  description = "Number of vCPU cores."
  type        = number
}

variable "cpu_type" {
  description = "CPU model exposed to the guest."
  type        = string
}

variable "memory_mb" {
  description = "Dedicated guest memory in MB."
  type        = number
}

variable "enable_ballooning" {
  description = "Whether to set floating memory equal to dedicated memory."
  type        = bool
}

variable "disk_size_gb" {
  description = "Guest boot disk size in GB."
  type        = number
}

variable "network_bridge" {
  description = "Proxmox bridge used by the VM."
  type        = string
}

variable "network_vlan_id" {
  description = "Optional VLAN ID. Use 0 for untagged."
  type        = number
}

variable "vm_username" {
  description = "Cloud-init username."
  type        = string
}

variable "vm_ssh_public_key" {
  description = "Cloud-init SSH public key content."
  type        = string
}

variable "vm_ipv4_address" {
  description = "Plain IPv4 address used to reach the guest."
  type        = string
}

variable "vm_ipv4_cidr" {
  description = "IPv4 configuration for cloud-init, either dhcp or CIDR notation."
  type        = string
}

variable "vm_ipv4_gateway" {
  description = "IPv4 gateway for the guest when using a static address."
  type        = string
}

variable "dns_servers" {
  description = "DNS servers passed to cloud-init."
  type        = list(string)
}

variable "dns_search_domain" {
  description = "Optional DNS search domain passed to cloud-init."
  type        = string
}

variable "vm_started" {
  description = "Whether the VM should be started after provisioning."
  type        = bool
}
