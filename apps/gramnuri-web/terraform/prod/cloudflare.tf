provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "cloudflare_dns_record" "web_record" {
  zone_id = var.cloudflare_zone_id
  name    = "landskipifyai.com"
  content = "ff8eab80-66b1-44ec-a485-94558ae3dc39.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
}


resource "cloudflare_dns_record" "www_record" {
  zone_id = var.cloudflare_zone_id
  name    = "www.landskipifyai.com"
  content = "ff8eab80-66b1-44ec-a485-94558ae3dc39.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
}
