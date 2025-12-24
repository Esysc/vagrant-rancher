resource "rancher2_catalog_v2" "bitnami" {
  provider   = rancher2.admin
  cluster_id = "local"
  name       = "bitnami"
  url        = "https://charts.bitnami.com/bitnami"

  depends_on = [rancher2_bootstrap.admin]
}

resource "rancher2_cluster_v2" "demo" {
  provider           = rancher2.admin
  name               = "demo-cluster"
  kubernetes_version = var.versions.kubernetes

  rke_config {
    networking {
      stack_preference = "ipv4"
    }
    # machine_global_config applies to all nodes - can't set different node-ip per node
    # For custom clusters, we need to configure node-ip on each node before registration
    # This will be done in the register-nodes.sh script
  }

  local_auth_endpoint {
    enabled = true
  }

  depends_on = [rancher2_catalog_v2.bitnami]
}

# =============================================================================
# Node Registration - Must remain as null_resource (SSH-based, no API)
# =============================================================================
resource "null_resource" "register_nodes" {
  depends_on = [
    rancher2_cluster_v2.demo,
    null_resource.vagrant_wait_ready
  ]

  provisioner "local-exec" {
    command     = "bash scripts/register-nodes.sh https://${local.rancher_server_ip} ${rancher2_bootstrap.admin.token} ${rancher2_cluster_v2.demo.cluster_v1_id} ${local.k8s_control_ip} ${local.k8s_worker_ip}"
    working_dir = "${path.module}/.."
  }
}

# Wait for cluster to become Active by polling Rancher API
resource "rancher2_cluster_sync" "demo_active" {
  provider   = rancher2.admin
  cluster_id = rancher2_cluster_v2.demo.cluster_v1_id

  # Ensure sync only starts after node registration commands ran
  depends_on = [null_resource.register_nodes]

  # Extra confirmation to reduce races after Active
  state_confirm = 3
}

# Fetch cluster after sync to ensure kube_config is populated
data "rancher2_cluster_v2" "demo_ready" {
  provider        = rancher2.admin
  name            = rancher2_cluster_v2.demo.name
  fleet_namespace = "fleet-default"

  depends_on = [rancher2_cluster_sync.demo_active]
}

# Write the cluster kubeconfig provided by Rancher to disk
resource "local_file" "demo_kubeconfig" {
  depends_on           = [data.rancher2_cluster_v2.demo_ready]
  content              = data.rancher2_cluster_v2.demo_ready.kube_config
  filename             = "${path.module}/../out/kubeconfig-demo-cluster"
  file_permission      = "0640"
  directory_permission = "0770"
}

# =============================================================================
# Kubernetes Provider for Demo Cluster - Used for app deployment
# =============================================================================
locals {
  kube_cfg         = yamldecode(data.rancher2_cluster_v2.demo_ready.kube_config)
  kube_cluster     = local.kube_cfg.clusters[0].cluster
  kube_user        = local.kube_cfg.users[0].user
  kube_host        = local.kube_cluster.server
  kube_ca_data     = try(local.kube_cluster["certificate-authority-data"], null)
  kube_client_cert = try(local.kube_user["client-certificate-data"], null)
  kube_client_key  = try(local.kube_user["client-key-data"], null)
  kube_token       = try(local.kube_user.token, try(local.kube_user["auth-provider"].config["access-token"], null))
}

provider "kubernetes" {
  alias                  = "demo_cluster"
  host                   = local.kube_host
  cluster_ca_certificate = local.kube_ca_data != null ? base64decode(local.kube_ca_data) : null
  # Prefer token auth when present; fall back to client certs if provided
  token              = local.kube_token
  client_certificate = local.kube_client_cert != null ? base64decode(local.kube_client_cert) : null
  client_key         = local.kube_client_key != null ? base64decode(local.kube_client_key) : null
}
