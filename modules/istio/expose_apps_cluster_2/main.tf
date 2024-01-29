provider "aws" {
  region = var.region
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


#Expose ISTIOD Cluster2
resource "kubernetes_manifest" "istiod_gateway2" {
  provider = kubernetes.cluster2
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "istiod-gateway"
      namespace = var.istio_namespace
    }
    spec = {
      selector = {
        istio = "eastwestgateway"
      }
      servers = [
        {
          port = {
            name     = "tls-istiod"
            number   = 15012
            protocol = "TLS"
          }
          tls = {
            mode = "PASSTHROUGH"
          }
          hosts = ["*"]
        },
        {
          port = {
            name     = "tls-istiodwebhook"
            number   = 15017
            protocol = "TLS"
          }
          tls = {
            mode = "PASSTHROUGH"
          }
          hosts = ["*"]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "istiod_virtual_service2" {
  provider = kubernetes.cluster2
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "istiod-vs"
      namespace = var.istio_namespace
    }
    spec = {
      hosts    = ["*"]
      gateways = ["istiod-gateway"]
      tls = [
        {
          match = [
            {
              port     = 15012
              sniHosts = ["*"]
            }
          ]
          route = [
            {
              destination = {
                host = "istiod.istio-system.svc.cluster.local"
                port = {
                  number = 15012
                }
              }
            }
          ]
        },
        {
          match = [
            {
              port     = 15017
              sniHosts = ["*"]
            }
          ]
          route = [
            {
              destination = {
                host = "istiod.istio-system.svc.cluster.local"
                port = {
                  number = 443
                }
              }
            }
          ]
        }
      ]
    }
  }
}

data "kubernetes_secret" "istio_reader" {
  provider   = kubernetes.cluster2
  depends_on = [kubernetes_secret.istio_reader]
  metadata {
    name      = "istio-reader-service-account-istio-remote-secret-token"
    namespace = "istio-system"
  }
}


resource "kubernetes_secret" "istio_reader" {
  provider = kubernetes.cluster2
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "istio-reader-service-account"
    }
    name      = "istio-reader-service-account-istio-remote-secret-token"
    namespace = "istio-system"
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_secret" "istio_remote_secret_cluster2" {
  provider = kubernetes.cluster1

  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "istio-reader-service-account"
    }
    labels = {
      "istio/multiCluster" = "true"
    }
    name      = "istio-remote-secret-${data.terraform_remote_state.eks_cluster_2.outputs.cluster2_name}"
    namespace = "istio-system"
  }

  data = {
    cluster2_name = templatefile("${path.module}/istio-remote-secret.tftpl",
      {
        cluster_certificate_authority_data = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_certificate_authority_data
        cluster_host                       = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_endpoint
        cluster_name                       = data.terraform_remote_state.eks_cluster_2.outputs.cluster2_name
        cluster_istio_reader_token         = data.kubernetes_secret.istio_reader.data["token"]
      }
    )
  }
}


