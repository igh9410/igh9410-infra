variable "cloudflare_api_key" {
  description = "Cloudflare API Key"
  type        = string
  sensitive   = true
}

variable "cloudflare_email" {
  description = "Cloudflare Email"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for your domain"
  type        = string
}

variable "github_token" {
  description = "GitHub Token"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository in format: OWNER/REPO"
  type        = string
  default     = "igh9410/igh9410-infra"
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  sensitive   = true
}

variable "gcp_project_id" {
  description = "GCP project that holds this environment's secrets (landskipify-dev)"
  type        = string
  default     = "gramnuri-dev-7d221"
}

variable "eso_service_account" {
  description = "External Secrets Operator service account (created in infrastructure/terraform/gcp.tf)"
  type        = string
  default     = "external-secrets-operator@igh9410-infra.iam.gserviceaccount.com"
}
