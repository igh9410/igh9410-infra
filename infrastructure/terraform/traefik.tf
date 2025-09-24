
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = "traefik-v3"
  version          = "37.1.1"
  create_namespace = true

  values = [
    file("${path.module}/values/traefik.yaml")
  ]

  depends_on = [
    helm_release.metallb
  ]
}
