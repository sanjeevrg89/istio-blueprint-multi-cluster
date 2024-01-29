/* output "ingress_gateway_cluster2_status" {
  description = "The status of the Istio Ingress Gateway installation in Cluster 1."
  value       = helm_release.ingress_gateway_cluster1.status
}

output "ingress_gateway_cluster2_version" {
  description = "The version of the Istio Ingress Gateway installed in Cluster 1."
  value       = helm_release.ingress_gateway_cluster1.version
}

output "ingress_gateway_cluster2_load_balancer_url" {
  description = "Load Balancer URL for the Istio Ingress Gateway in Cluster 2"
  value       = fileexists("${path.module}/ingress_gateway_url.txt") ? trimspace(file("${path.module}/ingress_gateway_url.txt")) : "Load balancer URL not available yet"
}


 */