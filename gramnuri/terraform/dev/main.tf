provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# Replace Container Registry with Artifact Registry
resource "google_project_service" "artifactregistry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "gramnuri_repo" {
  provider      = google
  location      = var.region
  repository_id = "gramnuri-repo"
  description   = "Docker repository for Gramnuri applications"
  format        = "DOCKER"

  depends_on = [
    google_project_service.artifactregistry
  ]
}

# Create a minimal GKE cluster (free tier)
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  # We can't create a cluster with no node pool defined, so we create the smallest possible default node pool
  # and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Replace the deprecated monitoring_service with logging_config and monitoring_config
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  # Wait for APIs to be enabled
  depends_on = [
    google_project_service.container,
    google_project_service.artifactregistry,
  ]

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# Create a separately managed node pool with e2-micro instances (free tier)
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 2
  node_config {
    # Upgrade from e2-micro to a slightly larger instance
    machine_type = "e2-small" # More memory and CPU

    # Google recommends custom service accounts with minimal permissions
    # Create a service account with minimal permissions in the console and reference it here
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
}

# Configure kubectl to use the new cluster
resource "null_resource" "configure_kubectl" {
  depends_on = [google_container_node_pool.primary_nodes]

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.cluster_name} --zone ${var.zone} --project ${var.project_id}"
  }
}

# Add this resource to create the GCS bucket for Terraform state
resource "google_storage_bucket" "terraform_state" {
  name          = "igh9410-terraform" # Unique bucket name
  location      = var.region
  force_destroy = true # Prevent accidental deletion

  # Enable versioning for state file tracking
  versioning {
    enabled = true
  }

  # Optional: Add lifecycle rules for state file management
  lifecycle_rule {
    condition {
      age = 30 # Keep old versions for 30 days
    }
    action {
      type = "Delete"
    }
  }

  # Ensure the bucket is created before other resources
  depends_on = [
    google_project_service.artifactregistry
  ]
}

