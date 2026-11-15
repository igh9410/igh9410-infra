provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

# The admin site in dev, through the same tunnel as dev.landskipifyai.com.
# There is no Secret Manager secret here: the admin app reads dev-gramnuri-web
# (see apps/gramnuri-admin/base/externalsecret.yaml).
resource "cloudflare_dns_record" "dev_admin" {
  zone_id = var.cloudflare_zone_id
  name    = "dev-admin.landskipifyai.com"
  content = "ff8eab80-66b1-44ec-a485-94558ae3dc39.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
}
