locals {
  # Admin UIs exposed through the cloudflared tunnel that require Access login
  access_protected_apps = {
    argocd  = "argocd.geonhyukim.com"
    grafana = "grafana.geonhyukim.com"
  }
}

resource "cloudflare_zero_trust_access_policy" "admin_emails" {
  account_id       = var.cloudflare_account_id
  name             = "admin-emails"
  decision         = "allow"
  session_duration = "24h"
  include = [
    for email in var.access_allowed_emails : { email = { email = email } }
  ]
}

resource "cloudflare_zero_trust_access_policy" "bypass_everyone" {
  account_id = var.cloudflare_account_id
  name       = "bypass-everyone"
  decision   = "bypass"
  include = [
    { everyone = {} }
  ]
}

resource "cloudflare_zero_trust_access_application" "admin" {
  for_each = local.access_protected_apps

  account_id       = var.cloudflare_account_id
  name             = each.key
  type             = "self_hosted"
  domain           = each.value
  session_duration = "24h"
  destinations = [
    { type = "public", uri = each.value }
  ]
  policies = [
    { id = cloudflare_zero_trust_access_policy.admin_emails.id, precedence = 1 }
  ]
}

# GitHub push webhook for ArgoCD; the more specific path takes precedence over
# the argocd app above. ArgoCD still validates the request's HMAC signature.
resource "cloudflare_zero_trust_access_application" "argocd_webhook" {
  account_id           = var.cloudflare_account_id
  name                 = "argocd-webhook"
  type                 = "self_hosted"
  domain               = "argocd.geonhyukim.com/api/webhook"
  app_launcher_visible = false
  destinations = [
    { type = "public", uri = "argocd.geonhyukim.com/api/webhook" }
  ]
  policies = [
    { id = cloudflare_zero_trust_access_policy.bypass_everyone.id, precedence = 1 }
  ]
}
