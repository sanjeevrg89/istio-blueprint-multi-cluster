provider "aws" {
  region = var.region
}

data "terraform_remote_state" "vpc_cluster_2" {
  backend = "local"
  config = {
    path = "${path.module}/../../vpc/vpc_cluster_2/terraform.tfstate"
  }
}

resource "random_string" "random2" {
  length  = 3
  upper   = false
  numeric = true
  special = false
}


data "aws_eks_cluster_auth" "cluster2" {
  name = module.eks_cluster_2.cluster_name
}

provider "kubernetes" {
  alias = "cluster2"
  host                   = module.eks_cluster_2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster_2.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster2.token
}

provider "helm" {
  alias = "helm_cluster2"
  kubernetes {
    host                   = module.eks_cluster_2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster_2.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster2.token
  }
}


# Istio Security Group for Cluster 2
resource "aws_security_group" "istio_cluster2" {
  name        = "${var.cluster_name}-2-istio-sg"
  description = "Security group for Istio communication in Cluster 2"
  vpc_id      = data.terraform_remote_state.vpc_cluster_2.outputs.vpc_id_cluster_2
}

# Istio Security Group Rules for Cluster 2
resource "aws_security_group_rule" "istio_ingress_15017_cluster2" {
  security_group_id = aws_security_group.istio_cluster2.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 15017
  to_port           = 15017
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "istio_ingress_15012_cluster2" {
  security_group_id = aws_security_group.istio_cluster2.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 15012
  to_port           = 15012
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "istio_ingress_443_cluster2" {
  security_group_id = aws_security_group.istio_cluster2.id
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "istio_egress_443_cluster2" {
  security_group_id = aws_security_group.istio_cluster2.id
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
}


module "eks_cluster_2" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16"

  cluster_name    = "${var.cluster_name}-${random_string.random2.result}"
  cluster_version = var.cluster_version
  cluster_endpoint_public_access = true
  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }
  vpc_id          = data.terraform_remote_state.vpc_cluster_2.outputs.vpc_id_cluster_2
  subnet_ids      = data.terraform_remote_state.vpc_cluster_2.outputs.private_subnets_ids_cluster_2
  eks_managed_node_groups = {
    default = {
      instance_types = ["m5.xlarge"]
      min_size               = 1
      max_size               = 5
      desired_size           = 3
      vpc_security_group_ids = [aws_security_group.istio_cluster2.id]
    }
  }

}

module "addons_cluster_2" {
  providers = {
    helm = helm.helm_cluster2
  }
  depends_on = [ module.eks_cluster_2 ]
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks_cluster_2.cluster_name
  cluster_endpoint  = module.eks_cluster_2.cluster_endpoint
  cluster_version   = module.eks_cluster_2.cluster_version
  oidc_provider_arn = module.eks_cluster_2.oidc_provider_arn

  enable_aws_load_balancer_controller = true
  enable_metrics_server = true

  tags = var.tags
}