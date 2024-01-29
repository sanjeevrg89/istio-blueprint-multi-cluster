# Output for Cluster 2 EKS Cluster ID
output "cluster2_id" {
  description = "The ID of the EKS Cluster 2"
  value       = module.eks_cluster_2.cluster_id
}

# Output for Cluster 2 EKS Cluster Endpoint
output "cluster2_endpoint" {
  description = "The endpoint for EKS Cluster 2"
  value       = module.eks_cluster_2.cluster_endpoint
}

# Output for Cluster 2 EKS Cluster Certificate Authority Data
output "cluster2_certificate_authority_data" {
  description = "The cluster CA certificate data for EKS Cluster 2"
  value       = module.eks_cluster_2.cluster_certificate_authority_data
}

# Output for Cluster 2 EKS Cluster Name
output "cluster2_name" {
  description = "The name of EKS Cluster 2"
  value       = module.eks_cluster_2.cluster_name
}