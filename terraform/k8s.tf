#############################################
# Kubernetes resources for HRM on EKS
# Managed by Terraform so apply/destroy is one command.
#############################################

data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name  # Replace module.eks.cluster_name with a variable
}

data "aws_eks_cluster_auth" "this" {
  name = var.eks_cluster_name  # Replace module.eks.cluster_name with a variable
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

resource "kubernetes_namespace_v1" "hrm" {
  metadata {
    name = var.hrm_namespace
  }
}

# Application secrets (Okta + DB + app key)
resource "kubernetes_secret_v1" "hrm" {
  metadata {
    name      = "hrm-secrets"
    namespace = kubernetes_namespace_v1.hrm.metadata[0].name
  }

  type = "Opaque"

  data = {
    OKTA_DOMAIN        = base64encode(var.okta_domain)
    OKTA_API_TOKEN     = base64encode(var.okta_api_token)
    SECRET_KEY         = base64encode(var.hrm_secret_key)
    DATABASE_HOST      = base64encode(var.hrm_db_host)
    DATABASE_PORT      = base64encode(var.hrm_db_port)
    DATABASE_NAME      = base64encode(var.hrm_db_name)
    DATABASE_USER      = base64encode(var.hrm_db_user)
    DATABASE_PASSWORD  = base64encode(var.hrm_db_password)
  }
}

resource "kubernetes_deployment_v1" "hrm" {
  metadata {
    name      = "hrm-web"
    namespace = kubernetes_namespace_v1.hrm.metadata[0].name
    labels = {
      app = "hrm-web"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "hrm-web"
      }
    }

    template {
      metadata {
        labels = {
          app = "hrm-web"
        }
      }

      spec {
        image_pull_secrets {
          name = "ecr-secret" # Ensure Kubernetes uses the ECR secret for authentication
        }

        container {
          name  = "hrm-web"
          image = "897931590595.dkr.ecr.eu-central-1.amazonaws.com/hrm-web:latest" # Updated to use the ECR image
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 5000
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.hrm.metadata[0].name
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 5000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "hrm" {
  metadata {
    name      = "hrm-service"
    namespace = kubernetes_namespace_v1.hrm.metadata[0].name
    labels = {
      app = "hrm-web"
    }
  }

  spec {
    selector = {
      app = "hrm-web"
    }

    port {
      port        = 5000
      target_port = 5000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "hrm" {
  metadata {
    name      = "hrm-ingress"
    namespace = kubernetes_namespace_v1.hrm.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.hrm.metadata[0].name
              port {
                number = 5000
              }
            }
          }
        }
      }
    }
  }
}

