provider "aws" {
  region = var.region
}

data "terraform_remote_state" "vpc_cluster_2" {
  backend = "local"
  config = {
    path = "${path.module}/../../vpc/vpc_cluster_2/terraform.tfstate"
  }
}

data "terraform_remote_state" "eks_cluster_2" {
  backend = "local"
  config = {
    path = "${path.module}/../../eks/eks_cluster_2/terraform.tfstate"
  }
}

data "aws_eks_cluster_auth" "cluster2" {
  name = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_name
}


provider "kubernetes" {
  alias                  = "cluster2"
  host                   = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_cluster_2.outputs.cluster2_certificate_authority_data)
  #token                  = data.aws_eks_cluster_auth.cluster2.token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks_cluster_2.outputs.cluster2_name]
  }
}

provider "helm" {
  alias = "helm_cluster2"
  kubernetes {
    host                   = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_cluster_2.outputs.cluster2_certificate_authority_data)
    #token                  = data.aws_eks_cluster_auth.cluster2.token
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks_cluster_2.outputs.cluster2_name]
    }
  }
}

# Create Istio namespace in Cluster 1
resource "kubernetes_namespace" "istio_system_cluster2" {
  provider = kubernetes.cluster2

  metadata {
    name = var.istio_namespace

    labels = {
      istio-injection             = "enabled"
      "topology.istio.io/network" = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_name
    }
  }
}

# Create Istio Ingress namespace in Cluster 1
resource "kubernetes_namespace" "istio_ingress_cluster2" {
  provider = kubernetes.cluster2

  metadata {
    name = "istio-ingress"

    labels = {
      istio-injection             = "enabled"
      "topology.istio.io/network" = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_name
    }
  }
}


# Create secret for custom certificates in Cluster 2
resource "kubernetes_secret" "cacerts_cluster2" {
  provider = kubernetes.cluster2

  metadata {
    name      = "cacerts"
    namespace = var.istio_namespace
  }

  data = {
    "ca-cert.pem"    = file("${path.module}/../../../certs/cluster2/ca-cert.pem")
    "ca-key.pem"     = file("${path.module}/../../../certs/cluster2/ca-key.pem")
    "cert-chain.pem" = file("${path.module}/../../../certs/cluster2/cert-chain.pem")
    "root-ca.key"    = file("${path.module}/../../../certs/cluster2/root-ca.key")
    "root-cert.pem"  = file("${path.module}/../../../certs/cluster2/root-cert.pem")
  }

}

# Istio Base Installation for Cluster 2
resource "helm_release" "istio_base_cluster2" {
  provider   = helm.helm_cluster2
  name       = "istio-base"
  chart      = "base"
  namespace  = var.istio_namespace
  repository = var.istio_chart_url
  version    = var.istio_chart_version
  wait       = true
}

# Istiod Installation for Cluster 2
resource "helm_release" "istiod_cluster2" {
  depends_on = [helm_release.istio_base_cluster2]
  provider   = helm.helm_cluster2
  name       = "istiod"
  chart      = "istiod"
  namespace  = var.istio_namespace
  repository = var.istio_chart_url
  version    = var.istio_chart_version
  wait       = true

  set {
    name  = "global.meshID"
    value = "mesh1"
  }

  set {
    name  = "global.multiCluster.clusterName"
    value = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_name
  }

  set {
    name  = "global.network"
    value = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_name
  }
}

# Ingress Gateway Installation for Cluster 2
resource "helm_release" "ingress_gateway_cluster2" {
  depends_on = [helm_release.istio_base_cluster2, helm_release.istiod_cluster2]
  provider   = helm.helm_cluster2
  name       = "istio-ingressgateway"
  chart      = "gateway"
  namespace  = "istio-ingress"
  repository = var.istio_chart_url
  version    = var.istio_chart_version
  wait       = true

  values = [
    yamlencode(
      {
        labels = {
          istio = "ingressgateway"
        }
        service = {
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
          }
        }
      }
    )
  ]
}


/* resource "null_resource" "get_ingress_gateway_url" {
  depends_on = [helm_release.ingress_gateway_cluster2]

  provisioner "local-exec" {
    command = "kubectl get svc istio-ingressgateway -n istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' > ${path.module}/ingress_gateway_url.txt"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/ingress_gateway_url.txt"
  }
} */
