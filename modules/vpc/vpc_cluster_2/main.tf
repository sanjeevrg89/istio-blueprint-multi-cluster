provider "aws" {
  region = var.region
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}
data "aws_availability_zones" "available" {}


resource "random_string" "random2" {
  length  = 3
  upper   = false
  numeric  = true
  special = false
}

module "vpc_cluster_2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name}-${random_string.random2.result}"
  cidr = var.cidr2

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.cidr2, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.cidr2, 8, k + 48)]

  enable_nat_gateway = var.enable_nat_gateway
  enable_vpn_gateway = var.enable_vpn_gateway

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = var.tags
}