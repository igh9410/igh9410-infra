# Create ArgoCD namespace
/*
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

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        insecure = true # For server's own endpoint being HTTP
        extraArgs = [ # List of strings for server command line
          "--insecure" # For insecure gRPC between components, if that was the intent
        ]
        config = { # Populates argocd-cm
          url = "https://argo.${var.domain_name}"
        }
        resources = {
          limits = {
            cpu    = "300m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
        ingress = {
          enabled = true
          hosts   = ["argo.${var.domain_name}"] # Explicitly setting the host
          paths   = ["/"]
          pathType = "Prefix"
          annotations = {
            # Your test annotation, can be kept or removed
            testDescription = "Terraform attempted to set this annotation for ArgoCD ingress"
            # Add other necessary annotations for Traefik if required
            # e.g., "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
          }
          # If you need to specify an ingressClassName for Traefik (usually not needed if Traefik is default)
          # ingressClassName = "traefik" 
        }
      } # end server block

      configs = {
        params = { # Populates argocd-cmd-params-cm
          "server.insecure" = "true" # Corresponds to original configs.params.server\.insecure
          # The original "server.config.admin.enabled" likely maps to here or configs.cm
          # Default for admin user is enabled if Dex is not used and no static password set.
          # If you had "server.config.admin.enabled = true", this might be:
          "server.admin.enabled" = "true" # Ensure this is a valid param key if used
        }
        cm = { # Populates argocd-cm
          # The original "server.config.admin.enabled = true" if it was meant for argocd-cm.
          # "admin.enabled" = "true" # string value
          # The original "server.config.proxy.enabled = true" is tricky as there's no direct boolean.
          # It might have been intended for "server.trusted_proxies" or similar.
          # For now, omitting direct proxy.enabled to avoid misconfiguration.
        }
      }

      repoServer = {
        resources = {
          limits = {
            memory = "256Mi"
          }
          requests = {
            memory = "128Mi"
          }
        }
      }

      applicationSet = { # This is a top-level key for the sub-chart
        enabled = false
      }
      notifications = { # This is a top-level key for the sub-chart
        enabled = false
      }
    })
  ]

  # Ensure Helm release depends on the cluster and namespace (dependency updated)
  depends_on = [
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

# Secret for GHCR access for ArgoCD Image Updater and Kubelet
# This secret's .dockerconfigjson data will be populated and refreshed by a separate mechanism (e.g., a CronJob)
# that generates GitHub App installation tokens.
resource "kubernetes_secret" "ghcr_creds" {
  metadata {
    name      = "ghcr-creds"
    namespace = "argocd"
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    # Placeholder data. The actual auth token will be managed by an external process.
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          username = "x-access-token"
          password = "placeholder-token" # This will be overwritten by the token refresh mechanism
          auth     = base64encode("x-access-token:placeholder-token")
        }
      }
    })
  }
  lifecycle {
    ignore_changes = [
      data, # Tell Terraform to ignore changes to the data field, as it's managed externally
    ]
  }
  depends_on = [
    # If you have a specific resource for creating the 'default' namespace managed by TF, depend on it.
    # Otherwise, for the built-in 'default' namespace, no explicit dependency is usually needed here.
    # For argocd-image-updater to access it from argocd namespace, ensure RBAC allows it or updater runs with broad permissions.
    kubernetes_namespace.argocd # Keeping this dependency if image updater still needs to know argocd ns exists, though secret is now in default.
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
}  */