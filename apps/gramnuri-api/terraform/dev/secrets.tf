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
    FIREBASE_PROJECT_ID          = var.firebase_project_id
    FIREBASE_CLIENT_EMAIL        = var.firebase_client_email
    FIREBASE_CLIENT_CERT_URL     = var.firebase_client_cert_url
    ENVIRONMENT                  = var.environment
    CLIENT_DOMAIN                = var.client_domain
    CLOUDFLARE_ACCOUNT_ID        = var.cloudflare_account_id
    CLOUDFLARE_ACCESS_KEY_ID     = var.cloudflare_access_key_id
    CLOUDFLARE_SECRET_ACCESS_KEY = var.cloudflare_secret_access_key
    R2_BUCKET_NAME               = var.r2_bucket_name
    AWS_ACCESS_KEY_ID            = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY        = var.aws_secret_access_key
    R2_CUSTOM_DOMAIN             = var.r2_custom_domain
    GEMINI_API_KEY               = var.gemini_api_key
  }
}

resource "kubernetes_secret" "gramnuri_discord_webhook_url" {
  metadata {
    name      = "gramnuri-discord-webhook-url"
    namespace = "monitoring"
  }

  type = "Opaque"

  data = {
    webhook_url = var.discord_webhook_url
  }
}