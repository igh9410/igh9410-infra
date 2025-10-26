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
    VITE_FIREBASE_API_KEY = var.firebase_api_key
    VITE_FIREBASE_AUTH_DOMAIN = var.firebase_auth_domain
    VITE_FIREBASE_PROJECT_ID = var.firebase_project_id
    VITE_FIREBASE_STORAGE_BUCKET = var.firebase_storage_bucket
    VITE_FIREBASE_MESSAGING_SENDER_ID = var.firebase_messaging_sender_id
    VITE_FIREBASE_APP_ID = var.firebase_app_id
    VITE_FIREBASE_MEASUREMENT_ID = var.firebase_measurement_id
    VITE_BACKEND_API_URL = var.backend_api_url
    VITE_INTERNAL_API_URL = var.internal_api_url
  }
}
