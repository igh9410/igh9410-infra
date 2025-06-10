
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Install ArgoCD using Helm - MANAGED MANUALLY VIA HELM
# resource "helm_release" "argocd" {
#   name       = "argocd"
#   repository = "https://argoproj.github.io/argo-helm"
#   chart      = "argo-cd"
#   version    = "7.8.13"
#   namespace  = kubernetes_namespace.argocd.metadata[0].name
#
#   values = [
#     file("values/argocd.yaml")
#   ]
#
#   # Ensure Helm release depends on the cluster and namespace (dependency updated)
#   depends_on = [
#     kubernetes_namespace.argocd
#   ]
# }

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

# ArgoCD Image Updater - MANAGED MANUALLY VIA HELM
# resource "helm_release" "argocd_image_updater" {
#   name       = "argocd-image-updater"
#   repository = "https://argoproj.github.io/argo-helm"
#   chart      = "argocd-image-updater"
#   namespace  = "argocd"
#   version    = "0.12.1"
#
#   values = [file("values/argocd-image-updater.yaml")]
#   depends_on = [
#     helm_release.argocd
#   ]
# }  

