
resource "kubernetes_namespace" "cloudflared_system" {
  metadata {
    labels = {
      "name" = "cloudflared-system"
    }
    name = "cloudflared-system"
  }
}

resource "helm_release" "cloudflared" {
  name       = "cloudflared"
  repository = "https://community-charts.github.io/helm-charts"
  chart      = "cloudflared"
  namespace  = "cloudflared-system"
  version    = "2.0.9"
  values = [
    file("values/cloudflared.yaml"),
    yamlencode({
      tunnelSecrets = {
        base64EncodedConfigJsonFile = base64encode(var.cloudflare_tunnel_credentials)
        base64EncodedPemFile        = base64encode(var.cloudflare_tunnel_cert_pem)
      }
    })
  ]
}  