output "vm_name" {
  description = "Reference VM name for the Proxmox target."
  value       = var.vm_name
}

output "vm_id" {
  description = "Proxmox VM ID for the reference VM."
  value       = proxmox_virtual_environment_vm.reference_vm.vm_id
}

output "expected_ipv4" {
  description = "Expected IPv4 address for the guest OS."
  value       = var.vm_ipv4_address
}

output "module_status" {
  description = "Module status for the Proxmox wrapper."
  value       = "vm-defined"
}

output "import_source_id" {
  description = "Effective import source ID used for VM disk initialization."
  value       = local.resolved_import_source_id
}
