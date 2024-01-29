# Outputs for VPC Cluster 1
output "vpc_id_cluster_1" {
  description = "The ID of the VPC for EKS Cluster 1"
  value       = module.vpc_cluster_1.vpc_id
}

output "public_subnets_ids_cluster_1" {
  description = "List of IDs of public subnets for EKS Cluster 1"
  value       = module.vpc_cluster_1.public_subnets
}

output "private_subnets_ids_cluster_1" {
  description = "List of IDs of private subnets for EKS Cluster 1"
  value       = module.vpc_cluster_1.private_subnets
}
