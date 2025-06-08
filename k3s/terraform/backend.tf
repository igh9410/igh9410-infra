terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }


  backend "s3" {
    bucket                      = "igh9410-terraform"
    key                         = "k3s/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    endpoints                   = { s3 = "https://c3b77c4aca2f20de101a1452ef946655.r2.cloudflarestorage.com" }
    # Credentials should be provided via AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
    # Endpoint should be provided via -backend-config flag or file during init
  }
}
