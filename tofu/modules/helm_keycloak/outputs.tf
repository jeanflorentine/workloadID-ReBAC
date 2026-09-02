output "release_name" {
  description = "Helm release name deployed for Keycloak."
  value       = helm_release.keycloak.name
}

output "namespace" {
  description = "Namespace where Keycloak is deployed."
  value       = helm_release.keycloak.namespace
}

output "chart_version" {
  description = "Resolved chart version for the deployed Keycloak release."
  value       = helm_release.keycloak.version
}