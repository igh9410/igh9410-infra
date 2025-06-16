provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "cloudflare_dns_record" "prod_api" {
  zone_id = var.cloudflare_zone_id
  name    = "test-artskorner.gramnuri.com"
  content = "3975cdcd-ffa2-462d-8a88-202402a706ab.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
}

/*
resource "cloudflare_r2_bucket" "gramnuri_r2_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "dev-gramnuri-bucket"
  location      = "APAC"
  storage_class = "Standard"
} */