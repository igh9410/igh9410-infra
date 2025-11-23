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
    DATABASE_URL                 = var.database_url
    FIREBASE_CREDENTIALS_JSON    = file("${path.module}/credentials/gramnuri-${var.environment}-firebase-adminsdk.json")
    FIREBASE_PROJECT_ID          = var.firebase_project_id
    ENVIRONMENT                  = var.environment
    CLIENT_DOMAIN                = var.client_domain
    CLOUDFLARE_ACCOUNT_ID        = var.cloudflare_account_id
    CLOUDFLARE_ACCESS_KEY_ID     = var.cloudflare_access_key_id
    CLOUDFLARE_SECRET_ACCESS_KEY = var.cloudflare_secret_access_key
    CLOUDFLARE_API_TOKEN         = var.cloudflare_api_token
    R2_BUCKET_NAME               = var.r2_bucket_name
    R2_CUSTOM_DOMAIN             = var.r2_custom_domain
    GEMINI_API_KEY               = var.gemini_api_key
  }
}

