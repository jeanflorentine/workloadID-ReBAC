resource "helm_release" "openfga" {
  name             = var.release_name
  repository       = "https://openfga.github.io/helm-charts"
  chart            = "openfga"
  version          = var.chart_version != "" ? var.chart_version : null
  namespace        = var.namespace
  create_namespace = false
  wait             = false
  timeout          = var.timeout_seconds

  values = [
    yamlencode({
      datastore = {
        engine = var.datastore_engine
      }
      service = {
        type = "ClusterIP"
      }
      log = {
        level = var.log_level
      }
    })
  ]
}