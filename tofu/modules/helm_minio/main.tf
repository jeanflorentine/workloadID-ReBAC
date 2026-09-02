resource "helm_release" "minio" {
  name             = var.release_name
  chart            = "oci://registry-1.docker.io/bitnamicharts/minio"
  version          = var.chart_version != "" ? var.chart_version : null
  namespace        = var.namespace
  create_namespace = false
  wait             = false
  timeout          = var.timeout_seconds

  values = [
    yamlencode({
      global = {
        security = {
          allowInsecureImages = true
        }
      }
      mode = "standalone"
      auth = {
        rootUser     = var.root_user
        rootPassword = var.root_password
      }
      image = {
        registry   = "docker.io"
        repository = "bitnamilegacy/minio"
      }
      console = {
        enabled = false
      }
      service = {
        type = "ClusterIP"
      }
    })
  ]
}