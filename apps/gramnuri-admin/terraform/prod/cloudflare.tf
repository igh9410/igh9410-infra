provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

# The admin site in prod, through the same tunnel as landskipifyai.com.
# Cloudflare Access in front of it is in infrastructure/terraform/access.tf.
# There is no Secret Manager secret here: the admin app reads prod-gramnuri-web
# (see apps/gramnuri-admin/base/externalsecret.yaml).
resource "cloudflare_dns_record" "admin" {
  zone_id = var.cloudflare_zone_id
  name    = "admin.landskipifyai.com"
  content = "ff8eab80-66b1-44ec-a485-94558ae3dc39.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Must stay proxied: Cloudflare Access only applies to proxied records
}
