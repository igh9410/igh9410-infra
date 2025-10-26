provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "cloudflare_dns_record" "dev_api" {
  zone_id = var.cloudflare_zone_id
  name    = "dev-api.landskipifyai.com"
  content = "ff8eab80-66b1-44ec-a485-94558ae3dc39.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
}



resource "cloudflare_r2_bucket" "gramnuri_r2_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "dev-gramnuri-bucket"
  location      = "APAC"
  storage_class = "Standard"
}

resource "cloudflare_r2_bucket" "gramnuri_static_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "gramnuri-static-bucket"
  location      = "APAC"
  storage_class = "Standard"
}