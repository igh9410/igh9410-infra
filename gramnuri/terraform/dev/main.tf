provider "vultr" {
  api_key = var.vultr_api_key
}

# Vultr Container Registry
resource "vultr_container_registry" "gramnuri_repo" {
  name   = "gramnuri"
  region = var.vultr_region
  public = false
  plan   = "start_up" # Choose the appropriate plan (start_up, business, premium)
  # start_up: 10 Repos, 10 GB Storage, 25 GB Transfer
  # Consider if this is sufficient or if a paid plan is needed.
}


