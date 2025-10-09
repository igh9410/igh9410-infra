provider "kubernetes" {
  config_path = var.kubeconfig_path
}


provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}


# Secret to store the GitHub App's private key
resource "kubernetes_secret" "github_app_private_key" {
  metadata {
    name      = "github-app-private-key"
    namespace = "github" # 
  }
  data = {
    # Ensure the key content does not have extra newlines before/after the BEGIN/END markers
    # The provider will base64 encode this string data.
    "privateKey.pem" = var.github_app_private_key_pem_content
  }
}

resource "kubernetes_secret" "cloudflared_tunnel_credentials" {
  metadata {
    name      = "cloudflared-tunnel-credentials"
    namespace = "cloudflared"
  }
  data = {
    "credentials.json" = var.cloudflare_tunnel_credentials
    "token"            = var.cloudflare_tunnel_cert_pem
  }
  type = "Opaque"
}

/* resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
  }
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
} */ 