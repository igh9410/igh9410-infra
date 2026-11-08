provider "google" {
  project = var.gcp_project_id
}

# Runtime secrets for gramnuri-api in dev, synced into the Secret
# gramnuri-secrets by apps/gramnuri-api/base/externalsecret.yaml.
#
# Terraform only creates the secret. The value is managed in the GCP console or
# with: gcloud secrets versions add dev-gramnuri-api --data-file=-
# It is one JSON object whose top-level keys are the env var names, e.g.
#   { "R2_BUCKET_NAME": "...", "FIREBASE_CREDENTIALS_JSON": { ...nested... } }
resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "app" {
  secret_id = "dev-gramnuri-api"
  labels = {
    app = "gramnuri-api"
    env = "dev"
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
