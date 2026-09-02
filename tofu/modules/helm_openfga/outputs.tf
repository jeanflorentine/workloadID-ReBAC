output "release_name" {
  description = "OpenFGA Helm release name."
  value       = helm_release.openfga.name
}

output "namespace" {
  description = "Namespace where OpenFGA is deployed."
  value       = helm_release.openfga.namespace
}