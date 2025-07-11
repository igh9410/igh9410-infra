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

resource "kubernetes_manifest" "metallb_ip_pool" {
  manifest = {
    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "IPAddressPool"
    "metadata" = {
      "name"      = "default-pool"
      "namespace" = "metallb-system"
    }
    "spec" = {
      "addresses" = [
        "192.168.45.200/32",
        "192.168.45.244/32",
      ]
    }
  }

  depends_on = [helm_release.metallb]
}

resource "kubernetes_manifest" "metallb_l2_advertisement" {
  manifest = {
    "apiVersion" = "metallb.io/v1beta1"
    "kind"       = "L2Advertisement"
    "metadata" = {
      "name"      = "default-l2"
      "namespace" = "metallb-system"
    }
    "spec" = {
      "ipAddressPools" = [
        "default-pool",
      ]
    }
  }

  depends_on = [kubernetes_manifest.metallb_ip_pool]
}
