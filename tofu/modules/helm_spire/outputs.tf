output "release_name" {
  description = "SPIRE Helm release name."
  value       = helm_release.spire.name
}

output "crds_release_name" {
  description = "SPIRE CRD Helm release name."
  value       = helm_release.spire_crds.name
}

output "namespace" {
  description = "Namespace where SPIRE is deployed."
  value       = helm_release.spire.namespace
}