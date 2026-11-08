# Google Cloud Provider Configuration
# This file manages the GCP project and IAM permissions for Secret Manager integration.

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Create the GCP Project
resource "google_project" "project" {
  name            = "igh9410-infra"
  project_id      = var.gcp_project_id
  billing_account = var.gcp_billing_account
  org_id          = var.gcp_org_id != "" ? var.gcp_org_id : null

  # Skip project deletion on destroy if you want to keep it
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Enable Necessary APIs
resource "google_project_service" "services" {
  for_each = toset([
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
  ])
  project = google_project.project.project_id
  service = each.value

  disable_on_destroy = false
}

# Create Service Account for External Secrets Operator (ESO)
resource "google_service_account" "eso_sa" {
  account_id   = "external-secrets-operator"
  display_name = "External Secrets Operator Service Account"
  project      = google_project.project.project_id

  depends_on = [google_project_service.services]
}

# Assign Secret Manager Secret Accessor Role
resource "google_project_iam_member" "eso_secret_accessor" {
  project = google_project.project.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.eso_sa.email}"

  depends_on = [google_service_account.eso_sa]
}

# Key for ESO to authenticate to Secret Manager from the homelab cluster.
# Workload Identity Federation would need a publicly reachable OIDC issuer for
# the cluster, so a single bootstrap key is used instead.
# Rotate with: terraform apply -replace=google_service_account_key.eso
resource "google_service_account_key" "eso" {
  service_account_id = google_service_account.eso_sa.name
}

# Bootstrap Secret referenced by the gcp-secret-manager ClusterSecretStore
# (infrastructure/external-secrets/cluster-secret-store.yaml).
resource "kubernetes_secret" "gcp_secret_manager_credentials" {
  metadata {
    name      = "gcp-secret-manager-credentials"
    namespace = "external-secrets"
  }

  type = "Opaque"

  data = {
    "secret-access-credentials" = base64decode(google_service_account_key.eso.private_key)
  }
}

# Application secrets synced into the cluster by ExternalSecrets.
#
# Terraform only creates the secret containers. Values are NOT managed here:
# each secret holds one JSON object (one top-level key per env var, nested JSON
# allowed) and is edited in the GCP console or with
#   gcloud secrets versions add <secret> --data-file=-
# Free tier: 6 active versions per billing account, so disable or destroy the
# previous version after adding a new one.
locals {
  app_secrets = {
    "gramnuri-api-dev"  = { app = "gramnuri-api", env = "dev" }
    "gramnuri-api-prod" = { app = "gramnuri-api", env = "prod" }
    "gramnuri-web-dev"  = { app = "gramnuri-web", env = "dev" }
    "gramnuri-web-prod" = { app = "gramnuri-web", env = "prod" }
  }
}

resource "google_secret_manager_secret" "app" {
  for_each = local.app_secrets

  project   = google_project.project.project_id
  secret_id = each.key
  labels    = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.services]
}
