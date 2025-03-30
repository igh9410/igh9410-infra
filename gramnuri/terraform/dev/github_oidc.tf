# Create a Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github_pool" {
  provider                  = google-beta
  project                   = var.project_id
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions"
}

# Create a Workload Identity Provider for GitHub Actions
resource "google_iam_workload_identity_pool_provider" "github_provider" {
  provider                           = google-beta
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Add this attribute condition to restrict to your repository
  attribute_condition = "attribute.repository==\"${var.github_repo}\""
}

# Create a Service Account for GitHub Actions
resource "google_service_account" "github_actions_sa" {
  project      = var.project_id
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
  description  = "Service account for GitHub Actions CI/CD"
}

# Grant Artifact Registry Writer permissions
resource "google_project_iam_member" "github_actions_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

# Grant GKE Developer permissions
resource "google_project_iam_member" "github_actions_gke" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

# Allow GitHub Actions to impersonate the service account
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.github_actions_sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_repo}"
  ]
}

# Output the Workload Identity Provider resource name for GitHub Actions
output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github_provider.name
}

# Output the Service Account email for GitHub Actions
output "github_actions_service_account" {
  value = google_service_account.github_actions_sa.email
}
