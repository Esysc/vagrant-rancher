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
    # machine_global_config applies to all nodes - can't set different node-ip per node
    # For custom clusters, we need to configure node-ip on each node before registration
    # This will be done in the register-nodes.sh script
  }

  local_auth_endpoint {
    enabled = true
  }

  depends_on = [rancher2_catalog_v2.bitnami]
}


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

resource "null_resource" "wait_cluster_ready" {
  depends_on = [null_resource.register_nodes]

  provisioner "local-exec" {
    command     = "bash scripts/wait-cluster-ready.sh https://${local.rancher_server_ip} ${rancher2_bootstrap.admin.token} ${rancher2_cluster_v2.demo.id}"
    working_dir = "${path.module}/.."
  }
}
