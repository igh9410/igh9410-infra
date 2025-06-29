# Create Tailscale namespace
resource "kubernetes_namespace" "tailscale" {
  metadata {
    name = "tailscale"
  }
}

# Create Kubernetes secret for Tailscale OAuth credentials
resource "kubernetes_secret" "tailscale_auth" {
  metadata {
    # CHANGE: Updated the secret name to match the ArgoCD Application manifest
    name      = "tailscale-operator-secrets"
    namespace = kubernetes_namespace.tailscale.metadata[0].name
  }

  type = "Opaque"

  data = {
    client_id     = var.tailscale_client_id
    client_secret = var.tailscale_client_secret
  }

  depends_on = [
    kubernetes_namespace.tailscale
  ]
}