/* output "cluster1_istio_ingress_gateway_service" {
  description = "The Istio Ingress Gateway service for Cluster 1"
  value       = kubernetes_service.istio_ingress_gateway_cluster1.metadata[0].name
}

output "cluster2_istio_ingress_gateway_service" {
  description = "The Istio Ingress Gateway service for Cluster 2"
  value       = kubernetes_service.istio_ingress_gateway_cluster2.metadata[0].name
} */