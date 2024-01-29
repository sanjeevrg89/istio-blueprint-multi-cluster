# Outputs for VPC Cluster 1# Outputs for VPC Cluster 2
output "vpc_id_cluster_2" {
  description = "The ID of the VPC for EKS Cluster 2"
  value       = module.vpc_cluster_2.vpc_id
}

output "public_subnets_ids_cluster_2" {
  description = "List of IDs of public subnets for EKS Cluster 2"
  value       = module.vpc_cluster_2.public_subnets
}

output "private_subnets_ids_cluster_2" {
  description = "List of IDs of private subnets for EKS Cluster 2"
  value       = module.vpc_cluster_2.private_subnets
}
