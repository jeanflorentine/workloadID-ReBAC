output "selected_target_platform" {
  description = "The currently selected platform for this environment."
  value       = var.target_platform
}

output "reference_vm_name" {
  description = "The reference VM name used across platform wrappers."
  value       = var.vm_name
}

output "reference_vm_ipv4" {
  description = "The IPv4 address expected for the reference VM."
  value       = var.vm_ipv4_address
}

output "k3s_bootstrap_status" {
  description = "Bootstrap status reported by the k3s module."
  value       = module.k3s_bootstrap.bootstrap_status
}

output "kubeconfig_fetch_command" {
  description = "Helper command to fetch kubeconfig after k3s bootstrap."
  value       = module.k3s_bootstrap.kubeconfig_fetch_command
}

output "proxmox_import_source_id" {
  description = "Import source ID used by the Proxmox VM module."
  value       = local.use_proxmox ? module.proxmox_vm[0].import_source_id : null
}
