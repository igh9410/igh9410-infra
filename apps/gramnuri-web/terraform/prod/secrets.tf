provider "google" {
  project = var.gcp_project_id
}

# Runtime secrets for gramnuri-web in prod, synced into the Secret
# gramnuri-client-secrets by apps/gramnuri-web/base/externalsecret.yaml.
#
# Terraform only creates the secret. The value is managed in the GCP console or
# with: gcloud secrets versions add prod-gramnuri-web --data-file=-
# It is one JSON object whose top-level keys are the env var names, e.g.
#   { "R2_BUCKET_NAME": "...", "FIREBASE_CREDENTIALS_JSON": { ...nested... } }
resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "app" {
  secret_id = "prod-gramnuri-web"
  labels = {
    app = "gramnuri-web"
    env = "prod"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

# Read access for ESO on this secret only.
resource "google_secret_manager_secret_iam_member" "eso" {
  secret_id = google_secret_manager_secret.app.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.eso_service_account}"
}
