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
    DATABASE_URL             = var.database_url
    FIREBASE_PROJECT_ID      = var.firebase_project_id
    FIREBASE_CLIENT_EMAIL    = var.firebase_client_email
    FIREBASE_CLIENT_CERT_URL = var.firebase_client_cert_url
    ENVIRONMENT              = var.environment
    CLIENT_DOMAIN            = var.client_domain
    TIKTOK_CLIENT_KEY        = var.tiktok_client_key
    TIKTOK_CLIENT_SECRET     = var.tiktok_client_secret
    TIKTOK_REDIRECT_URI      = var.tiktok_redirect_uri
  }
}
