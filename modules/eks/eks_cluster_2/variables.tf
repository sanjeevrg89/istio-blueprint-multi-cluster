variable "cluster_name" {
    description = "The name of the EKS cluster"
    type = string
    default = "eks"
}

variable "region" {
    description = "VPC region"
    type = string
    default = "us-west-2"
}

variable "cluster_version" {
    description = "The name of the EKS cluster"
    type = string
    default = "1.28"
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

variable "cluster_endpoint_public_access"{
    default = true
}