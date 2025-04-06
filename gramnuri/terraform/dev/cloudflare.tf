# Configure the Cloudflare provider
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Create an A record for your domain pointing to the load balancer IP
resource "cloudflare_record" "dev_api" {
  zone_id = var.cloudflare_zone_id
  name    = "dev-api"
  content = data.kubernetes_service.gramnuri_api.status.0.load_balancer.0.ingress.0.ip
  type    = "A"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
}

# Add a new record for ArgoCD
resource "cloudflare_record" "argocd" {
  zone_id = var.cloudflare_zone_id
  name    = "argo"
  content = data.kubernetes_service.argocd_server.status.0.load_balancer.0.ingress.0.ip
  type    = "A"
  ttl     = 1
  proxied = true # Enable Cloudflare proxy for SSL
}

# TikTok Developer Site Verification TXT Record
resource "cloudflare_record" "tiktok_verification" {
  zone_id = var.cloudflare_zone_id
  name    = "@" # Root domain
  type    = "TXT"
  value   = "tiktok-developers-site-verification=YwePFWSAWYnljIRZTaLXKQqFVNjtGahq"
  ttl     = 1 # Automatic TTL
}

# Output the full domain URLs
output "api_domain_url" {
  value = "https://${cloudflare_record.dev_api.name}.${var.domain_name}"
}

output "argocd_domain_url" {
  value = "https://${cloudflare_record.argocd.name}.${var.domain_name}"
}

output "argocd_ip" {
  value = data.kubernetes_service.argocd_server.status.0.load_balancer.0.ingress.0.ip
}