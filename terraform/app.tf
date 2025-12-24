# =============================================================================
# JWT Key Generation - Replaces null_resource "generate_jwt_keys"
# =============================================================================

# Generate RSA key pair for JWT using Terraform's tls provider
resource "tls_private_key" "jwt" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# =============================================================================
# Kubernetes Resources - Replaces null_resource "deploy_train_app"
# =============================================================================

# Namespace
resource "kubernetes_namespace_v1" "train_app" {
  provider = kubernetes.demo_cluster

  metadata {
    name = "train-app"
  }

  depends_on = [rancher2_cluster_sync.demo_active]
}

# JWT Keys Secret - Replaces shell script that generates and applies secret
resource "kubernetes_secret_v1" "jwt_keys" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "jwt-keys"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  data = {
    "private.pem" = tls_private_key.jwt.private_key_pem
    "public.pem"  = tls_private_key.jwt.public_key_pem
  }

  type = "Opaque"
}

# Backend ConfigMap
resource "kubernetes_config_map_v1" "backend_config" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "backend-config"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  data = {
    APP_ENV        = "prod"
    APP_DEBUG      = "0"
    DATABASE_URL   = "postgresql://postgres:postgres@db:5432/train_routing"
    JWT_SECRET_KEY = "/var/jwt/private.pem"
    JWT_PUBLIC_KEY = "/var/jwt/public.pem"
  }
}

# Frontend ConfigMap
resource "kubernetes_config_map_v1" "frontend_config" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "frontend-config"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  data = {
    VITE_API_URL = "/api/v1"
  }
}

# Database Secret
resource "kubernetes_secret_v1" "db_secret" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "db-secret"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  data = {
    POSTGRES_PASSWORD = "postgres"
    POSTGRES_USER     = "postgres"
    POSTGRES_DB       = "train_routing"
  }

  type = "Opaque"
}

# PostgreSQL Deployment
resource "kubernetes_deployment_v1" "postgres" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:16-alpine"

          port {
            container_port = 5432
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.db_secret.metadata[0].name
            }
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "postgres-storage"
          empty_dir {}
        }
      }
    }
  }
}

# PostgreSQL Service
resource "kubernetes_service_v1" "db" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "db"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
    }
  }
}

# Backend Deployment
resource "kubernetes_deployment_v1" "backend" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "backend"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          name  = "backend"
          image = "ghcr.io/esysc/defi-fullstack/backend:latest"

          port {
            container_port = 8000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.backend_config.metadata[0].name
            }
          }

          volume_mount {
            name       = "jwt-keys"
            mount_path = "/var/jwt"
            read_only  = true
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "200m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }
        }

        volume {
          name = "jwt-keys"
          secret {
            secret_name = kubernetes_secret_v1.jwt_keys.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.postgres]
}

# Backend Service
resource "kubernetes_service_v1" "backend" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "backend"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  spec {
    selector = {
      app = "backend"
    }

    session_affinity = "ClientIP"
    session_affinity_config {
      client_ip {
        timeout_seconds = 10800
      }
    }

    port {
      port        = 8000
      target_port = 8000
    }
  }
}

# Frontend Deployment
resource "kubernetes_deployment_v1" "frontend" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = "ghcr.io/esysc/defi-fullstack/frontend:latest"

          port {
            container_port = 3000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.frontend_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "300m"
            }
          }
        }
      }
    }
  }
}

# Frontend Service
resource "kubernetes_service_v1" "frontend" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "frontend"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  spec {
    selector = {
      app = "frontend"
    }

    port {
      port        = 3000
      target_port = 3000
    }
  }
}

# Nginx Deployment
resource "kubernetes_deployment_v1" "nginx" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "ghcr.io/esysc/defi-fullstack/nginx:latest"

          port {
            container_port = 80
          }

          port {
            container_port = 443
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "200m"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment_v1.backend,
    kubernetes_deployment_v1.frontend
  ]
}

# Nginx Service (NodePort)
resource "kubernetes_service_v1" "nginx" {
  provider = kubernetes.demo_cluster

  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace_v1.train_app.metadata[0].name
  }

  spec {
    type = "NodePort"

    selector = {
      app = "nginx"
    }

    session_affinity = "ClientIP"
    session_affinity_config {
      client_ip {
        timeout_seconds = 10800
      }
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      node_port   = 30080
    }

    port {
      name        = "https"
      port        = 443
      target_port = 443
      node_port   = 30443
    }
  }
}
