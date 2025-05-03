# Optional: Output ArgoCD server URL


# Output the full domain URLs
/*
output "api_domain_url" {
  value = "https://${cloudflare_record.dev_api.name}.${var.domain_name}"
} */

output "argocd_server_url" {
  value = "https://${data.kubernetes_service.argocd_server.status.0.load_balancer.0.ingress.0.ip}"
}
output "argocd_domain_url" {
  value = "https://${cloudflare_record.argocd.name}.${var.domain_name}"
} 

output "argocd_ip" {
  value = data.kubernetes_service.argocd_server.status.0.load_balancer.0.ingress.0.ip
}
