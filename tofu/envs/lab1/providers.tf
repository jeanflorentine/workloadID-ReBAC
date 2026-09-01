variable "target_platform" {
  description = "Selected target platform: proxmox, local-hypervisor, or openstack."
  type        = string

  validation {
    condition     = contains(["proxmox", "local-hypervisor", "openstack"], var.target_platform)
    error_message = "target_platform must be one of: proxmox, local-hypervisor, openstack."
  }
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "openstack" {}
provider "proxmox" {
  endpoint      = var.proxmox_endpoint
  insecure      = var.proxmox_insecure
  min_tls       = var.proxmox_min_tls
  random_vm_ids = false
}
