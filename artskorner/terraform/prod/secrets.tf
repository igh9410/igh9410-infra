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
  }
}
