variable "cluster_name" {
  description = "Name of the Vultr Kubernetes cluster"
  type        = string
  default     = "gramnuri-dev-cluster"
}

variable "image_name" {
  description = "Name of the Docker image"
  type        = string
  default     = "gramnuri-api"
}

variable "image_tag" {
  description = "Tag of the Docker image"
  type        = string
  default     = "latest"
}

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

variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for your domain"
  type        = string
}

variable "domain_name" {
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

variable "vultr_api_key" {
  description = "Vultr API Key"
  type        = string
  sensitive   = true
}

variable "vultr_region" {
  description = "Vultr region for resources"
  type        = string
  default     = "icn" # Seoul
}

variable "vke_version" {
  description = "Vultr Kubernetes Engine (VKE) version"
  type        = string
  default     = "v1.32.2+1" # Updated to a more recent patch. Check Vultr UI/CLI for the latest available.
}

variable "vke_node_plan" {
  description = "Vultr instance plan for worker nodes"
  type        = string
  default     = "vc2-1c-2gb" # Example: 1 vCPU, 2GB RAM
}

variable "vke_node_count" {
  description = "Initial number of worker nodes in the default pool"
  type        = number
  default     = 2
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

