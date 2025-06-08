provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# Configure Helm provider to connect to the new VKE cluster
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# Secret to store the GitHub App's private key
resource "kubernetes_secret" "github_app_private_key" {
  metadata {
    name      = "github-app-private-key"
    namespace = "kube-system" # Choose a secure, appropriate namespace
  }
  data = {
    # Ensure the key content does not have extra newlines before/after the BEGIN/END markers
    # The provider will base64 encode this string data.
    "privateKey.pem" = var.github_app_private_key_pem_content
  }
}
/*
resource "helm_release" "sealed-secrets" {
  name       = "sealed-secrets"
  repository = "https://bitnami-labs.github.io/sealed-secrets"
  chart      = "sealed-secrets"
  namespace  = "kube-system"
  version    = "2.17.2"

  values = [file("values/sealed-secrets.yaml")]
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
    value = "NodePort"
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
} */

