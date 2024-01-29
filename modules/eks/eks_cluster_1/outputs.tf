# Output for Cluster 1 EKS Cluster ID
output "cluster1_id" {
  description = "The ID of the EKS Cluster 1"
  value       = module.eks_cluster_1.cluster_id
}

# Output for Cluster 1 EKS Cluster Endpoint
output "cluster1_endpoint" {
  description = "The endpoint for EKS Cluster 1"
  value       = module.eks_cluster_1.cluster_endpoint
}

# Output for Cluster 1 EKS Cluster Certificate Authority Data
output "cluster1_certificate_authority_data" {
  description = "The cluster CA certificate data for EKS Cluster 1"
  value       = module.eks_cluster_1.cluster_certificate_authority_data
}

# Output for Cluster 1 EKS Cluster Name
output "cluster1_name" {
  description = "The name of EKS Cluster 1"
  value       = module.eks_cluster_1.cluster_name
}
