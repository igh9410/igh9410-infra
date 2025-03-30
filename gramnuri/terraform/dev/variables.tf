variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast3"
}

variable "zone" {
  description = "GCP zone for zonal resources"
  type        = string
  default     = "asia-northeast3-a"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
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

variable "project_number" {
  description = "GCP Project Number (not the project ID)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format: OWNER/REPO"
  type        = string
  default     = "your-org/your-repo"
}

