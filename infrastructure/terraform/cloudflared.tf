/*resource "helm_release" "cloudflared" {
  name       = "cloudflared"
  repository = "https://community-charts.github.io/helm-charts"
  chart      = "cloudflared"
  version    = "2.2.1"
  namespace  = "cloudflared"

  values = [
    file("values/cloudflared.yaml")
  ]


}
*/