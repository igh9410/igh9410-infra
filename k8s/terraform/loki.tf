resource "cloudflare_r2_bucket" "loki_chunk_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "igh9410-loki-chunk"
  location      = "apac"
  storage_class = "Standard"
} 