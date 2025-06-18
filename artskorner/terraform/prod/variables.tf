variable "database_url" {
  description = "Database URL"
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

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
  sensitive   = true
}


variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "cloudflare_access_token" {
  description = "Cloudflare Access Token"
  type        = string
  sensitive   = true
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

variable "jwt_secret" {
  description = "JWT Secret"
  type        = string
  sensitive   = true
}
