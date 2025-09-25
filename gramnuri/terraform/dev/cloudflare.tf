provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "cloudflare_dns_record" "dev_api" {
  zone_id = var.cloudflare_zone_id
  name    = "dev-api.gramnuri.com"
  content = "ff8eab80-66b1-44ec-a485-94558ae3dc39.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
}

# Cloudflare Worker DNS Record for dev.gramnuri.com
resource "cloudflare_dns_record" "web" {
  zone_id = var.cloudflare_zone_id
  name    = "dev.gramnuri.com" # Subdomain for the dev website
  # Change content to the worker's hostname (remove https:// and trailing /)
  content = "gramnuri-web.athanasia9410.workers.dev"
  # Change type from A to CNAME
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Keep proxied enabled for Cloudflare benefits
}


resource "cloudflare_r2_bucket" "gramnuri_r2_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "dev-gramnuri-bucket"
  location      = "APAC"
  storage_class = "Standard"
}