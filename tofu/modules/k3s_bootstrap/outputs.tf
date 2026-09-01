output "bootstrap_status" {
  description = "Status for the k3s bootstrap module."
  value       = "bootstrap-defined"
}

output "kubeconfig_fetch_command" {
  description = "Helper command to fetch the kubeconfig from the guest after bootstrap."
  value       = "ssh -i ${var.ssh_private_key_path} -p ${var.ssh_port} ${var.ssh_username}@${var.target_host} sudo cat /etc/rancher/k3s/k3s.yaml"
}

output "cluster_api_server" {
  description = "Expected k3s API server endpoint."
  value       = "https://${var.target_host}:6443"
}
