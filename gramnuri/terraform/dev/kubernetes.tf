# Define the Vultr Kubernetes Engine (VKE) Cluster
resource "vultr_kubernetes" "vke_cluster" {
  label   = var.cluster_name
  region  = var.vultr_region
  version = var.vke_version
  # High availability is recommended for production, but might add cost.
  # Set to true if needed.
  # high_availability = false 

  # Define the Default Node Pool inline
  node_pools {
    node_quantity = var.vke_node_count
    plan          = var.vke_node_plan
    label         = "default-pool" # Label for the node pool
    auto_scaler   = true
    min_nodes     = 1
    max_nodes     = 3 # Adjust as needed
    

    # Optional: Add Kubernetes taints or labels if needed
    # taints {
    #   key = "key"
    #   value = "value"
    #   effect = "NoSchedule"
    # }
    # label = {
    #   key1 = "value1"
    #   key2 = "value2"
    # }
  }
}

provider "kubernetes" {
  host                   = "https://${vultr_kubernetes.vke_cluster.endpoint}:6443"
  cluster_ca_certificate = base64decode(vultr_kubernetes.vke_cluster.cluster_ca_certificate)
  client_key             = base64decode(vultr_kubernetes.vke_cluster.client_key)
  client_certificate     = base64decode(vultr_kubernetes.vke_cluster.client_certificate)
}

# Configure Helm provider to connect to the new VKE cluster
provider "helm" {
  kubernetes {
    host                   = "https://${vultr_kubernetes.vke_cluster.endpoint}:6443"
    cluster_ca_certificate = base64decode(vultr_kubernetes.vke_cluster.cluster_ca_certificate)
    client_key             = base64decode(vultr_kubernetes.vke_cluster.client_key)
    client_certificate     = base64decode(vultr_kubernetes.vke_cluster.client_certificate)
  }
}

# Remove the kubernetes_deployment and kubernetes_service resources
# They are now managed by ArgoCD

# Keep this data source to get the LoadBalancer IP for Cloudflare

# Create ArgoCD namespace

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Install ArgoCD using Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.13"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # Basic ArgoCD configuration
  set {
    name  = "server.service.type"
    value = "ClusterIP"
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

  # Ensure Helm release depends on the cluster and namespace (dependency updated)
  depends_on = [
    vultr_kubernetes.vke_cluster,
    kubernetes_namespace.argocd
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

# Install Traefik Ingress Controller
resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "35.2.0" # Specify a version for stability
  namespace  = "kube-system" # Recommended namespace for Traefik
  timeout    = 600      # Increased timeout to 10 minutes

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "entryPoints.web.http.redirections.entryPoint.to"
    value = "websecure"
  }
  set {
    name  = "entryPoints.web.http.redirections.entryPoint.scheme"
    value = "https"
  }
  set {
    name  = "entryPoints.web.http.redirections.entryPoint.permanent"
    value = "true"
  }


  
  # If you are managing TLS directly on Traefik (e.g. Let's Encrypt)
  # you would configure TLS options for websecure here.
  # For example:
  # set {
  #   name = "entryPoints.websecure.http.tls.enabled"
  #   value = "true"
  # }
  # set {
  #   name = "entryPoints.websecure.http.tls.certResolver"
  #   value = "myresolver" # Replace with your cert resolver name
  # }

  set {
    name = "providers.kubernetesIngress.publishedService.enabled"
    value = "true"
  }

  # Add resource limits/requests as needed
  # set {
  #   name = "resources.limits.cpu"
  #   value = "500m"
  # }
  # set {
  #   name = "resources.limits.memory"
  #   value = "512Mi"
  # }

  depends_on = [
    vultr_kubernetes.vke_cluster
  ]
}

# Data source for Traefik LoadBalancer service
data "kubernetes_service" "traefik_lb" {
  metadata {
    name      = "traefik" # Default service name for Traefik chart
    namespace = "kube-system" 
  }
  depends_on = [
    helm_release.traefik
  ]
}

# Uncomment and ensure dependencies are correct
resource "helm_release" "argocd_image_updater" {
  name       = "argocd-image-updater"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  namespace  = "argocd"
  version    = "0.12.1"

  values = [file("values/argocd-image-updater.yaml")]
  depends_on = [
    helm_release.argocd
  ]
}

# TODO: If argocd-image-updater needs to access the private Vultr Container Registry,
# create a Kubernetes secret (type: kubernetes.io/dockerconfigjson) 
# with the registry credentials obtained from vultr_container_registry.gramnuri_repo
# and configure the image updater to use it.
