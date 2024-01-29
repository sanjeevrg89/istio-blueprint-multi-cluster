variable "name" {
    description = "Base name to be used on all the resources as identifier, a random string will be appended"
    type = string
    default = "eks"
}

variable "cidr1" {
    description = "CIDR block for the VPC"
    type = string
    default = "10.1.0.0/16"
}

variable "region" {
    description = "VPC region"
    type = string
    default = "us-west-2"
}

variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks."
  type        = bool
  default = true
}

variable "enable_vpn_gateway" {
  description = "Should be true if you want to provision a VPN Gateway."
  type        = bool
  default = false
}

variable "tags" {
  description = "A map of tags to add to all resources."
  type        = map(string)
  default     = {
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

