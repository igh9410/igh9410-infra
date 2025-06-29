variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "domain_name" {
  description = "Your domain name (e.g., geonhyukim.com)"
  type        = string
  default     = "geonhyukim.com"
}

variable "github_token" {
  description = "GitHub Token"
  type        = string
  sensitive   = true
}

variable "github_app_private_key_pem_content" {
  description = "The content of the GitHub App's private key PEM file. Ensure no extra newlines."
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

variable "r2_access_token" {
  description = "R2 Access Token"
  type        = string
  sensitive   = true
}

variable "r2_access_key_id" {
  description = "R2 Access Key ID"
  type        = string
  sensitive   = true
}

variable "r2_secret_access_key" {
  description = "R2 Secret Access Key"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "cloudflare_tunnel_credentials" {
  description = "Cloudflare Tunnel Credentials"
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_cert_pem" {
  description = "Cloudflare Tunnel Certificate PEM"
  type        = string
  sensitive   = true
}

variable "tailscale_client_id" {
  description = "Tailscale OAuth2 Client ID"
  type        = string
  sensitive   = true
}

variable "tailscale_client_secret" {
  description = "Tailscale OAuth2 Client Secret"
  type        = string
  sensitive   = true
}