provider "google" {
  project = var.gcp_project_id
}

# Runtime secrets for gramnuri-api in prod, synced into the Secret
# gramnuri-secrets by apps/gramnuri-api/base/externalsecret.yaml.
#
# Terraform only creates the secret. The value is managed in the GCP console or
# with: gcloud secrets versions add prod-gramnuri-api --data-file=-
# It is one JSON object whose top-level keys are the env var names, e.g.
#   { "R2_BUCKET_NAME": "...", "FIREBASE_CREDENTIALS_JSON": { ...nested... } }
resource "google_secret_manager_secret" "app" {
  secret_id = "prod-gramnuri-api"
  labels = {
    app = "gramnuri-api"
    env = "prod"
  }

  replication {
    auto {}
  }
}
