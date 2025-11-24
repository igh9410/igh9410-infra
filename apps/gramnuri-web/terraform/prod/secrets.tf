provider "kubernetes" {
  config_path = var.kubeconfig_path
}

resource "kubernetes_secret" "gramnuri_client_secrets" {
  metadata {
    name      = "gramnuri-client-secrets"
    namespace = var.environment
  }

  type = "Opaque"

  data = {
    FIREBASE_API_KEY = var.firebase_api_key
    FIREBASE_AUTH_DOMAIN = var.firebase_auth_domain
    FIREBASE_PROJECT_ID = var.firebase_project_id
    FIREBASE_STORAGE_BUCKET = var.firebase_storage_bucket
    FIREBASE_MESSAGING_SENDER_ID = var.firebase_messaging_sender_id
    FIREBASE_APP_ID = var.firebase_app_id
    FIREBASE_MEASUREMENT_ID = var.firebase_measurement_id
    BACKEND_API_URL = var.backend_api_url
    INTERNAL_API_URL = var.internal_api_url
  }
}
