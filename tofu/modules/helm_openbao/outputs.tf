output "release_name" {
  description = "OpenBao Helm release name."
  value       = helm_release.openbao.name
}

output "namespace" {
  description = "Namespace where OpenBao is deployed."
  value       = helm_release.openbao.namespace
}