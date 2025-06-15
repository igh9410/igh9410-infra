provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "dev_api" {
  zone_id = var.cloudflare_zone_id
  name    = "dev-api"
  content = "3975cdcd-ffa2-462d-8a88-202402a706ab.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
} 

# Cloudflare Worker DNS Record for dev.gramnuri.com
resource "cloudflare_record" "web" {
  zone_id = var.cloudflare_zone_id
  name    = "dev" # Subdomain for the dev website
  # Change content to the worker's hostname (remove https:// and trailing /)
  content = "gramnuri-web.athanasia9410.workers.dev"
  # Change type from A to CNAME
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Keep proxied enabled for Cloudflare benefits
}

# TikTok Developer Site Verification TXT Record
resource "cloudflare_record" "tiktok_verification" {
  zone_id = var.cloudflare_zone_id
  name    = "dev" 
  type    = "TXT"
  content   = "tiktok-developers-site-verification=uuYK4VKuqEC5wSbmq1klvqViJEiml8IC"
  ttl     = 1 # Automatic TTL
}

resource "cloudflare_r2_bucket" "gramnuri_r2_bucket" {
  account_id = var.cloudflare_account_id
  name = "dev-gramnuri-bucket"
  location = "apac"
  storage_class = "Standard"
}