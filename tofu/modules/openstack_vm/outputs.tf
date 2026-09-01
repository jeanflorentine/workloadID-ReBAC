output "vm_name" {
  description = "Reference VM name for the OpenStack target."
  value       = var.vm_name
}

output "module_status" {
  description = "Scaffold status for this module."
  value       = local.module_status
}
