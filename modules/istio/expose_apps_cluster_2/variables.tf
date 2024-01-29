variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default = "eks"
}

variable "region" {
    description = "VPC region"
    type = string
    default = "us-west-2"
}

variable "istio_namespace" {
  description = "The namespace where Istio components will be installed"
  type        = string
  default     = "istio-system"
}