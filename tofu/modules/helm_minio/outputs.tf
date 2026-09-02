output "release_name" {
  description = "MinIO Helm release name."
  value       = helm_release.minio.name
}

output "namespace" {
  description = "Namespace where MinIO is deployed."
  value       = helm_release.minio.namespace
}