resource "helm_release" "keycloak" {
  name             = var.release_name
  chart            = "oci://registry-1.docker.io/bitnamicharts/keycloak"
  version          = var.chart_version
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
      auth = {
        adminUser     = var.admin_username
        adminPassword = var.admin_password
      }
      image = {
        registry   = "docker.io"
        repository = "bitnamilegacy/keycloak"
      }
      production = false
      proxy      = "edge"
      service = {
        type = "ClusterIP"
      }
      postgresql = {
        enabled = true
        image = {
          registry   = "docker.io"
          repository = "bitnamilegacy/postgresql"
        }
      }
    })
  ]
}