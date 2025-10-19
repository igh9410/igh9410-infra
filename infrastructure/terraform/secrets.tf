resource "kubernetes_secret" "cloudflare_r2_credentials" {
  metadata {
    name      = "cloudflare-r2-credentials"
    namespace = "monitoring"
  }
  data = {
    # Ensure the key content does not have extra newlines before/after the BEGIN/END markers
    # The provider will base64 encode this string data.
    "ACCESS_KEY_ID"     = var.r2_access_key_id
    "ACCESS_SECRET_KEY" = var.r2_secret_access_key
  }
}

resource "kubernetes_secret" "cnpg_cluster_backup_credentials" {
  metadata {
    name      = "cnpg-cluster-backup-credentials"
    namespace = "cnpg-database"
  }
  data = {
    "ACCESS_KEY_ID"     = var.r2_access_key_id
    "ACCESS_SECRET_KEY" = var.r2_secret_access_key
  }
}

resource "kubernetes_secret" "prod_cnpg_cluster_backup_credentials" {
  metadata {
    name      = "cnpg-cluster-backup-credentials"
    namespace = "prod-cnpg-database"
  }
  data = {
    "ACCESS_KEY_ID"     = var.r2_access_key_id
    "ACCESS_SECRET_KEY" = var.r2_secret_access_key
  }
}

resource "kubernetes_secret" "tailscale_oauth_credentials" {
  metadata {
    name      = "operator-oauth"
    namespace = "tailscale"
  }
  data = {
    "client_id"     = var.tailscale_oauth_client_id
    "client_secret" = var.tailscale_oauth_client_secret
  }
}

resource "kubernetes_secret" "ghcr_image_pull_secrets" {
  for_each = var.app_namespaces
  metadata {
    name      = "ghcr-image-pull-secrets"
    namespace = each.value
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    # Placeholder data. The actual auth token will be managed by an external process.
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          username = "igh9410"
          password = var.github_pat
          email    = var.cloudflare_email
          auth     = base64encode("igh9410:${var.github_pat}")
        }
      }
    })
  }
}

resource "kubernetes_secret" "dev_alarms_webhook_url" {
  metadata {
    name      = "dev-alarms-webhook-url"
    namespace = "monitoring"
  }

  type = "Opaque"

  data = {
    webhook_url = var.dev_alarms_discord_webhook_url
  }
}