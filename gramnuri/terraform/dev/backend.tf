terraform {
  required_providers {
    vultr = {
      source = "vultr/vultr"
      # Pin to a specific version for stability
      version = "~> 2.18"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
  # Keep other providers if needed (e.g., helm, kubernetes, cloudflare will be defined elsewhere or are already)

  # backend "s3" { # Example for Vultr Object Storage - Configure separately
  #   endpoint                    = "ewr1.vultrobjects.com" # Change to your bucket's region endpoint
  #   bucket                      = "your-terraform-state-bucket"
  #   key                         = "gramnuri/dev/terraform.tfstate"
  #   region                      = "us-east-1" # Must be a valid AWS region, even for S3 compatible storage
  #   access_key                  = "YOUR_VULTR_OBJ_ACCESS_KEY"
  #   secret_key                  = "YOUR_VULTR_OBJ_SECRET_KEY"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   force_path_style            = true
  # }


  backend "s3" {
    bucket                      = "igh9410-terraform"
    key                         = "gramnuri/dev/terraform.tfstate"
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
