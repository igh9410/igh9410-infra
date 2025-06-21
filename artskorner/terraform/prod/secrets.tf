provider "kubernetes" {
  config_path = var.kubeconfig_path
}

resource "kubernetes_secret" "artskorner_secrets" {
  metadata {
    name      = "artskorner-secrets"
    namespace = var.environment
  }

  type = "Opaque"

  data = {
    DATABASE_URL                 = var.database_url
    ADMIN_JWT_SECRET                   = var.admin_jwt_secret
    CLOUDFLARE_ACCOUNT_ID             = var.cloudflare_account_id
    CLOUDFLARE_ACCESS_KEY_ID          = var.cloudflare_access_key_id
    CLOUDFLARE_SECRET_ACCESS_KEY      = var.cloudflare_secret_access_key
    R2_BUCKET_NAME                    = var.r2_bucket_name
  }
}
