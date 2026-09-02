resource "helm_release" "openbao" {
  name             = var.release_name
  repository       = "https://openbao.github.io/openbao-helm"
  chart            = "openbao"
  version          = var.chart_version != "" ? var.chart_version : null
  namespace        = var.namespace
  create_namespace = false
  wait             = false
  timeout          = var.timeout_seconds

  values = [
    yamlencode({
      server = {
        dev = {
          enabled      = true
          devRootToken = var.root_token
        }
      }
      ui = {
        enabled = true
      }
      injector = {
        enabled = false
      }
      csi = {
        enabled = false
      }
    })
  ]
}