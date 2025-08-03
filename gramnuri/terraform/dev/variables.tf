variable "database_url" {
  description = "Database URL"
  type        = string
}

variable "firebase_project_id" {
  description = "Firebase Project ID"
  type        = string
}

variable "firebase_client_email" {
  description = "Firebase Client Email"
  type        = string
}

variable "firebase_client_cert_url" {
  description = "Firebase Client Cert URL"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

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

variable "client_domain" {
  description = "Your domain name (e.g., gramnuri.com)"
  type        = string
  default     = "gramnuri.com"
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

variable "tiktok_client_key" {
  description = "TikTok Client Key"
  type        = string
  sensitive   = true
}

variable "tiktok_client_secret" {
  description = "TikTok Client Secret"
  type        = string
  sensitive   = true
}

variable "tiktok_redirect_uri" {
  description = "TikTok Redirect URI"
  type        = string
  default     = "https://dev.gramnuri.com/oauth/callback/tiktok"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "cloudflare_access_key_id" {
  description = "Cloudflare Access Key ID"
  type        = string
  sensitive   = true
}

variable "cloudflare_secret_access_key" {
  description = "Cloudflare Secret Access Key"
  type        = string
  sensitive   = true
}

variable "r2_bucket_name" {
  description = "R2 Bucket Name"
  type        = string
  default     = "dev-gramnuri-bucket"
}
