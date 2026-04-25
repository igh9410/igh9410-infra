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

# Create a Service Account Key for ESO (to be used as a Kubernetes Secret)
# Note: In a production environment, Workload Identity is preferred.
resource "google_service_account_key" "eso_sa_key" {
  service_account_id = google_service_account.eso_sa.name
}

# Store the GCP SA Key in a Kubernetes Secret for ESO to use
resource "kubernetes_secret" "gcp_sa_key" {
  metadata {
    name      = "gcp-sa-key"
    namespace = "argocd" # We'll put it here for now or move to eso namespace later
  }

  data = {
    "key.json" = base64decode(google_service_account_key.eso_sa_key.private_key)
  }

  depends_on = [google_service_account_key.eso_sa_key]
}
