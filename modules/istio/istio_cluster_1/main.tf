provider "aws" {
  region = var.region
}

data "terraform_remote_state" "vpc_cluster_1" {
  backend = "local"
  config = {
    path = "${path.module}/../../vpc/vpc_cluster_1/terraform.tfstate"
  }
}

data "terraform_remote_state" "eks_cluster_1" {
  backend = "local"
  config = {
    path = "${path.module}/../../eks/eks_cluster_1/terraform.tfstate"
  }
}

data "aws_eks_cluster_auth" "cluster1" {
  name = data.terraform_remote_state.eks_cluster_1.outputs.cluster1_name
}


provider "kubernetes" {
  alias                  = "cluster1"
  host                   = data.terraform_remote_state.eks_cluster_1.outputs.cluster1_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_cluster_1.outputs.cluster1_certificate_authority_data)
  #token                  = data.aws_eks_cluster_auth.cluster1.token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks_cluster_1.outputs.cluster1_name]
  }

}



provider "helm" {
  alias = "helm_cluster1"
  kubernetes {
    host                   = data.terraform_remote_state.eks_cluster_1.outputs.cluster1_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_cluster_1.outputs.cluster1_certificate_authority_data)
    #token                  = data.aws_eks_cluster_auth.cluster1.token
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks_cluster_1.outputs.cluster1_name]
    }
  }
}


# Create Istio namespace in Cluster 1
resource "kubernetes_namespace" "istio_system_cluster1" {
  provider = kubernetes.cluster1

  metadata {
    name = var.istio_namespace

    labels = {
      istio-injection             = "enabled"
      "topology.istio.io/network" = data.terraform_remote_state.eks_cluster_1.outputs.cluster1_name
    }
  }
}

# Create Istio Ingress namespace in Cluster 1
resource "kubernetes_namespace" "istio_ingress_cluster1" {
  provider = kubernetes.cluster1

  metadata {
    name = "istio-ingress"

    labels = {
      istio-injection             = "enabled"
      "topology.istio.io/network" = data.terraform_remote_state.eks_cluster_1.outputs.cluster1_name
    }
  }
}


# Create secret for custom certificates in Cluster 1
resource "kubernetes_secret" "cacerts_cluster1" {
  provider = kubernetes.cluster1

  metadata {
    name      = "cacerts"
    namespace = var.istio_namespace
  }

  data = {
    "ca-cert.pem"    = file("${path.module}/../../../certs/cluster1/ca-cert.pem")
    "ca-key.pem"     = file("${path.module}/../../../certs/cluster1/ca-key.pem")
    "cert-chain.pem" = file("${path.module}/../../../certs/cluster1/cert-chain.pem")
    "root-ca.key"    = file("${path.module}/../../../certs/cluster1/root-ca.key")
    "root-cert.pem"  = file("${path.module}/../../../certs/cluster1/root-cert.pem")
  }

}



# Istio Base Installation for Cluster 1
resource "helm_release" "istio_base_cluster1" {
  provider   = helm.helm_cluster1
  name       = "istio-base"
  chart      = "base"
  namespace  = var.istio_namespace
  repository = var.istio_chart_url
  version    = var.istio_chart_version
  wait       = true
}


# Istiod Installation for Cluster 1
resource "helm_release" "istiod_cluster1" {
  depends_on = [helm_release.istio_base_cluster1]
  provider   = helm.helm_cluster1
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
    value = data.terraform_remote_state.eks_cluster_1.outputs.cluster1_name
  }

  set {
    name  = "global.network"
    value = data.terraform_remote_state.eks_cluster_1.outputs.cluster1_name
  }
}

# Ingress Gateway Installation for Cluster 1
resource "helm_release" "ingress_gateway_cluster1" {
  depends_on = [helm_release.istio_base_cluster1, helm_release.istiod_cluster1]
  provider   = helm.helm_cluster1
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
  depends_on = [helm_release.ingress_gateway_cluster1]

  provisioner "local-exec" {
    command = "kubectl get svc istio-ingressgateway -n istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' > ${path.module}/ingress_gateway_url.txt"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/ingress_gateway_url.txt"
  }
}
 */



