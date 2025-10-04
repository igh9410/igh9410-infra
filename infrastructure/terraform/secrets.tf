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