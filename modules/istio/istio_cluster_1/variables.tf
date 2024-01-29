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

variable "istio_chart_url" {
  description = "The URL for the Istio Helm chart repository"
  type        = string
  default     = "https://istio-release.storage.googleapis.com/charts"
}

variable "istio_chart_version" {
  description = "The version of the Istio Helm chart to use"
  type        = string
  default     = "1.20"
}