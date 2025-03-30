output "kubernetes_cluster_name" {
  value = google_container_cluster.primary.name
}

output "kubernetes_cluster_host" {
  value     = google_container_cluster.primary.endpoint
  sensitive = true
}

output "load_balancer_ip" {
  value = data.kubernetes_service.gramnuri_api.status.0.load_balancer.0.ingress.0.ip
  depends_on = [
    null_resource.configure_kubectl
  ]
}

output "load_balancer_url" {
  value = "https://${google_container_cluster.primary.endpoint}/docs"
}
