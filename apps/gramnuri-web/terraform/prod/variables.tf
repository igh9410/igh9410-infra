variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "firebase_api_key" {
  description = "Firebase API Key"
  type        = string
}

variable "firebase_auth_domain" {
  description = "Firebase Auth Domain"
  type        = string
}

variable "firebase_project_id" {
  description = "Firebase Project ID"
  type        = string
}

variable "firebase_storage_bucket" {
  description = "Firebase Storage Bucket"
  type        = string
}

variable "firebase_messaging_sender_id" {
  description = "Firebase Messaging Sender ID"
  type        = string
}

variable "firebase_app_id" {
  description = "Firebase App ID"
  type        = string
}

variable "firebase_measurement_id" {
  description = "Firebase Measurement ID"
  type        = string
}

variable "backend_api_url" {
  description = "Backend API URL"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}
  
variable "cloudflare_email" {
  description = "Cloudflare Email"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_key" {
  description = "Cloudflare API Key"
  type        = string
  sensitive   = true
}

variable "internal_api_url" {
  description = "Internal API URL"
  type        = string
}