locals {
  namespace_count = length(var.namespace_names)
}

resource "kubernetes_namespace_v1" "foundation" {
  for_each = toset(var.namespace_names)

  metadata {
    name = each.value
  }
}
