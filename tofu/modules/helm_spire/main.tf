resource "helm_release" "spire_crds" {
  name             = "${var.release_name}-crds"
  repository       = "https://spiffe.github.io/helm-charts-hardened/"
  chart            = "spire-crds"
  version          = var.chart_version != "" ? var.chart_version : null
  namespace        = var.namespace
  create_namespace = false
  wait             = false
  timeout          = var.timeout_seconds
}

resource "helm_release" "spire" {
  name             = var.release_name
  repository       = "https://spiffe.github.io/helm-charts-hardened/"
  chart            = "spire"
  version          = var.chart_version != "" ? var.chart_version : null
  namespace        = var.namespace
  create_namespace = false
  wait             = false
  timeout          = var.timeout_seconds

  depends_on = [helm_release.spire_crds]

  values = [
    yamlencode({
      global = {
        spire = {
          trustDomain = var.trust_domain
        }
      }
      "spire-server" = {
        enabled = true
      }
      "spire-agent" = {
        enabled = true
      }
    })
  ]
}