provider "kubernetes" {
  config_path = var.kubeconfig_path
}

resource "kubernetes_secret" "gramnuri_secrets" {
  metadata {
    name      = "gramnuri-secrets"
    namespace = var.environment
  }

  type = "Opaque"

  data = {
    client_domain            = var.client_domain
    database_url             = var.database_url
    environment              = var.environment
    firebase_client_cert_url = var.firebase_client_cert_url
    firebase_client_email    = var.firebase_client_email
    firebase_project_id      = var.firebase_project_id
    tiktok_client_key        = var.tiktok_client_key
    tiktok_client_secret     = var.tiktok_client_secret
    tiktok_redirect_uri      = var.tiktok_redirect_uri
  }
}
