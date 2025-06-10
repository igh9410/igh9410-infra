resource "kubernetes_namespace" "cloudflared_system" {
  metadata {
    labels = {
      "name" = "cloudflared-system"
    }
    name = "cloudflared-system"
  }
}
/*
resource "kubernetes_secret" "cloudflared_tunnel_secret" {
  metadata {
    name      = "cloudflared-tunnel-secret"
    namespace = kubernetes_namespace.cloudflared_system.metadata[0].name
  }
  data = {
    "cert.pem"          = var.cloudflare_tunnel_cert_pem
    "credentials.json"  = var.cloudflare_tunnel_credentials
  }
  type = "Opaque"
}


resource "helm_release" "cloudflared" {
  name       = "cloudflared"
  repository = "https://community-charts.github.io/helm-charts"
  chart      = "cloudflared"
  namespace  = "cloudflared-system" # Should match the secret's namespace
  version    = "2.0.5"   # As you requested
  values = [
    file("values/cloudflared.yaml")
  ]
  
  depends_on = [kubernetes_secret.cloudflared_tunnel_secret]
} */

resource "cloudflare_record" "grafana" {
  zone_id = var.cloudflare_zone_id
  name    = "grafana"
  content = "3975cdcd-ffa2-462d-8a88-202402a706ab.cfargotunnel.com"
  type    = "CNAME"
  proxied = false  # Set to false for tunnel, true if you want additional Cloudflare proxy features
  comment = "CNAME record for Grafana via Cloudflare Tunnel"
}
