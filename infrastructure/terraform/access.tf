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

# Skip the Access login when browsing from the home network
resource "cloudflare_zero_trust_access_policy" "bypass_home_ips" {
  account_id = var.cloudflare_account_id
  name       = "bypass-home-ips"
  decision   = "bypass"
  include = [
    for ip in var.access_bypass_ips : { ip = { ip = ip } }
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
    { id = cloudflare_zero_trust_access_policy.bypass_home_ips.id, precedence = 1 },
    { id = cloudflare_zero_trust_access_policy.admin_emails.id, precedence = 2 }
  ]
}

# Landskipify admin sites (apps/gramnuri-admin). They have their own allow
# policy so that admin-site users, such as the studio designer, do not also
# get through to ArgoCD and Grafana. Access is a second gate: the admin app
# still requires its own admin session from an admin_users account.
# The DNS records live in apps/gramnuri-admin/terraform/{dev,prod}.
locals {
  landskipify_admin_apps = {
    "gramnuri-admin-dev"  = "dev-admin.landskipifyai.com"
    "gramnuri-admin-prod" = "admin.landskipifyai.com"
  }
}

resource "cloudflare_zero_trust_access_policy" "landskipify_admin_emails" {
  account_id       = var.cloudflare_account_id
  name             = "landskipify-admin-emails"
  decision         = "allow"
  session_duration = "24h"
  include = [
    for email in var.landskipify_admin_emails : { email = { email = email } }
  ]
}

resource "cloudflare_zero_trust_access_application" "landskipify_admin" {
  for_each = local.landskipify_admin_apps

  account_id       = var.cloudflare_account_id
  name             = each.key
  type             = "self_hosted"
  domain           = each.value
  session_duration = "24h"
  destinations = [
    { type = "public", uri = each.value }
  ]
  policies = [
    { id = cloudflare_zero_trust_access_policy.bypass_home_ips.id, precedence = 1 },
    { id = cloudflare_zero_trust_access_policy.landskipify_admin_emails.id, precedence = 2 }
  ]
}

# Pre-launch gate for the prod Landskipify site: until launch only the
# Landskipify admins (and the home network) can open it. Each hostname is its
# own Access app because an apex domain does not cover www. Delete this block
# to launch. api.landskipifyai.com stays open: the browser calls it directly
# with fetch, which cannot follow an Access login redirect.
locals {
  landskipify_prelaunch_apps = {
    "landskipify-prod-prelaunch"     = "landskipifyai.com"
    "landskipify-prod-prelaunch-www" = "www.landskipifyai.com"
  }
}

resource "cloudflare_zero_trust_access_application" "landskipify_prelaunch" {
  for_each = local.landskipify_prelaunch_apps

  account_id       = var.cloudflare_account_id
  name             = each.key
  type             = "self_hosted"
  domain           = each.value
  session_duration = "24h"
  destinations = [
    { type = "public", uri = each.value }
  ]
  policies = [
    { id = cloudflare_zero_trust_access_policy.bypass_home_ips.id, precedence = 1 },
    { id = cloudflare_zero_trust_access_policy.landskipify_admin_emails.id, precedence = 2 }
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
