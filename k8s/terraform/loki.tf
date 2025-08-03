resource "cloudflare_r2_bucket" "loki_chunk_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "igh9410-loki-chunk"
  location      = "apac"
  storage_class = "Standard"
}

resource "cloudflare_r2_bucket" "loki_ruler_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "igh9410-loki-ruler"
  location      = "apac"
  storage_class = "Standard"
}

resource "cloudflare_r2_bucket" "loki_admin_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "igh9410-loki-admin"
  location      = "apac"
  storage_class = "Standard"
} 