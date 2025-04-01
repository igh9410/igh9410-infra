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


/*
resource "kubernetes_manifest" "argocd_application_dev" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "gramnuri-dev"
      namespace = "argocd"
    }
    annotations = {
      # 1. Define the image to track
      # Alias 'gramnuri-api' maps to the full GAR path constructed from main.tf resources/variables
      "argocd-image-updater.argoproj.io/image-list" = "gramnuri-api=${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.gramnuri_repo.repository_id}/gramnuri-api"

      # 2. Define the update strategy for the 'gramnuri-api' alias
      "argocd-image-updater.argoproj.io/gramnuri-api.update-strategy" = "latest" # Use the most recently pushed tag

      # 3. (Optional) Allow specific tags (e.g., using regex)
      "argocd-image-updater.argoproj.io/gramnuri-api.allow-tags" = "regexp:^.*$" # Allow any tag for now

      # 4. Define how to write the update back to Git
      # Use the 'github_access' secret (ensure token has write access)
      "argocd-image-updater.argoproj.io/write-back-method" = "git:secret:argocd/github_access"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/igh9410/igh9410-infra.git"
        targetRevision = "HEAD"
        path           = "gramnuri/k8s/overlays/dev"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
      ignoreDifferences = [
        {
          group     = ""
          kind      = "Secret"
          name      = "gramnuri-secrets"
          namespace = "default"
          jsonPointers = [
            "/*"
          ]
        }
      ]
    }
  }

  field_manager {
    force_conflicts = true
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_secret.github_access
  ]
} */

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
