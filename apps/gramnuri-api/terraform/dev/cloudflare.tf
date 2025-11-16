provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "cloudflare_dns_record" "dev_api" {
  zone_id = var.cloudflare_zone_id
  name    = "dev-api.landskipifyai.com"
  content = "ff8eab80-66b1-44ec-a485-94558ae3dc39.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1    # Auto TTL
  proxied = true # Set to false if you don't want to use Cloudflare's proxy
}



resource "cloudflare_r2_bucket" "gramnuri_r2_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "dev-gramnuri-bucket"
  location      = "APAC"
  storage_class = "Standard"
}

resource "cloudflare_r2_bucket" "gramnuri_static_bucket" {
  account_id    = var.cloudflare_account_id
  name          = "gramnuri-static-bucket"
  location      = "APAC"
  storage_class = "Standard"
}

/*
resource "cloudflare_r2_bucket_lifecycle" "gramnuri_r2_bucket_lifecycle" {
  account_id = var.cloudflare_account_id
  bucket_name = "dev-gramnuri-bucket"
  rules = [{
    id = "Expire user uploaded images after 14 days"
    conditions = {
      prefix = "users/images/"
    }
    enabled = true
    abort_multipart_uploads_transition = {
      condition = {
        max_age = 7 * 24 * 60 * 60
        type = "Age"
      }
    }
    delete_objects_transition = {
      condition = {
        max_age = 14 * 24 * 60 * 60
        type = "Age"
      }
    }
  }]
} */