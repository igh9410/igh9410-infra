resource "kubernetes_namespace" "metallb_system" {
  metadata {
    name = "metallb-system"
    labels = {
      "name" = "metallb-system"
    }
  }
}

resource "helm_release" "metallb" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  namespace  = kubernetes_namespace.metallb_system.metadata[0].name
  version    = "0.15.2" # Pinning version for stability
  
  values = [file("values/metallb.yaml")]
  depends_on = [
    kubernetes_namespace.metallb_system
  ]
}
