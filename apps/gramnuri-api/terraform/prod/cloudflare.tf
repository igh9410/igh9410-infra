provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "cloudflare_dns_record" "api_record" {
  zone_id = var.cloudflare_zone_id
  name    = "api.landskipifyai.com"
  content = "ff8eab80-66b1-44ec-a485-94558ae3dc39.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
}



resource "cloudflare_r2_bucket" "gramnuri_r2_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "prod-gramnuri-bucket"
  location      = "APAC"
  storage_class = "Standard"
}


