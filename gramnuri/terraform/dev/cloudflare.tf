provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
/*
# Create an A record for your domain pointing to the load balancer IP
resource "cloudflare_record" "dev_api" {
  zone_id = var.cloudflare_zone_id
  name    = "dev-api"
  content = data.kubernetes_service.traefik_lb.status.0.load_balancer.0.ingress.0.ip
  type    = "A"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
} 

# Add a new record for ArgoCD
resource "cloudflare_record" "argocd" {
  zone_id = var.cloudflare_zone_id
  name    = "argo"
  content = data.kubernetes_service.traefik_lb.status.0.load_balancer.0.ingress.0.ip
  type    = "A"
  ttl     = 1
  proxied = true # Enable Cloudflare proxy for SSL
} */

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