provider "kubernetes" {
  # Keep this provider configuration for data sources
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

# Add this data source
data "google_client_config" "default" {}

# Add Helm provider for ArgoCD installation
provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
  }
}

# Remove the kubernetes_deployment and kubernetes_service resources
# They are now managed by ArgoCD

# Keep this data source to get the LoadBalancer IP for Cloudflare
data "kubernetes_service" "gramnuri_api" {
  metadata {
    name      = "dev-gramnuri-api"
    namespace = "default" # Update if you change the namespace
  }
  depends_on = [
    null_resource.configure_kubectl,
    # Add a dependency on ArgoCD setup
    helm_release.argocd
  ]
}

# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Install ArgoCD using Helm with optimized settings
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.13"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Basic ArgoCD configuration
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }


  # Enable insecure mode for Cloudflare Flexible SSL
  set {
    name  = "server.insecure"
    value = "true"
  }



  # Add resource limits to prevent OOM issues
  set {
    name  = "server.resources.limits.cpu"
    value = "300m"
  }
  set {
    name  = "server.resources.limits.memory"
    value = "512Mi"
  }
  set {
    name  = "server.resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "server.resources.requests.memory"
    value = "256Mi"
  }

  # Limit repo server resources
  set {
    name  = "repoServer.resources.limits.memory"
    value = "256Mi"
  }
  set {
    name  = "repoServer.resources.requests.memory"
    value = "128Mi"
  }

  # Disable unnecessary components to save resources
  set {
    name  = "applicationSet.enabled"
    value = "false"
  }
  set {
    name  = "notifications.enabled"
    value = "false"
  }

  # Add these critical settings
  set {
    name  = "server.extraArgs"
    value = "{--insecure}"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  # Configure external URL explicitly
  set {
    name  = "server.config.url"
    value = "https://argo.${var.domain_name}"
  }

  set {
    name  = "server.config.admin.enabled"
    value = "true"
  }

  # Add ingress configuration
  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.hosts[0]"
    value = "argo.${var.domain_name}"
  }

  # Proxy settings
  set {
    name  = "server.config.proxy.enabled"
    value = "true"
  }

  depends_on = [
    google_container_node_pool.primary_nodes,
    null_resource.configure_kubectl
  ]
}

# Optional: Output ArgoCD server URL
output "argocd_server_url" {
  value = "https://${data.kubernetes_service.argocd_server.status.0.load_balancer.0.ingress.0.ip}"
}

# Optional: Data source for ArgoCD server service
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }
  depends_on = [
    helm_release.argocd
  ]
}


# Create a secret for GitHub credentials
resource "kubernetes_secret" "github_access" {
  metadata {
    name      = "github-access"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = "https://github.com/igh9410/igh9410-infra.git"
    username = "igh9410"
    password = var.github_token # Reference to your PAT in variables
  }

  depends_on = [
    kubernetes_namespace.argocd
  ]
}



resource "helm_release" "argocd_image_updater" {
  name       = "argocd-image-updater"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  namespace  = "argocd"
  version    = "0.12.0"

  values = [file("values/argocd-image-updater.yaml")]
  depends_on = [
    helm_release.argocd
  ]
}

# Create a Google service account for Argo CD Image Updater
resource "google_service_account" "argocd_image_updater" {
  account_id   = "argocd-image-updater"
  display_name = "Service Account for Argo CD Image Updater"
  project      = var.project_id
}

# Grant the service account access to Artifact Registry
resource "google_project_iam_member" "argocd_image_updater_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.argocd_image_updater.email}"
}

# Allow the Kubernetes service account to impersonate the Google service account
resource "google_service_account_iam_binding" "argocd_image_updater_workload_identity" {
  service_account_id = google_service_account.argocd_image_updater.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[argocd/argocd-image-updater]"
  ]
}

