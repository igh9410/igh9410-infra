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
    # The endpoint and credentials should be provided during 'terraform init'.
    # This keeps sensitive data out of version control.
    #
    # Option 1 (Recommended): Use a backend configuration file.
    # Create a 'backend.conf' file (and add it to .gitignore) with the following:
    #   endpoints  = { s3 = "https://<YOUR_ACCOUNT_ID>.r2.cloudflarestorage.com" }
    #   access_key = "..."
    #   secret_key = "..."
    # Then run: terraform init -backend-config=backend.conf
    #
    # Option 2: Use environment variables for credentials.
    # Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in your shell,
    # and provide only the endpoint in the config file.
  }
}
