resource "null_resource" "vagrant_up" {
  provisioner "local-exec" {
    command     = "bash scripts/vagrant-parallel-up.sh ${local.rancher_server_name} ${local.k8s_control_name} ${local.k8s_worker_name}"
    working_dir = "${path.module}/.."
  }

  provisioner "local-exec" {
    when        = destroy
    command     = "vagrant destroy -f"
    working_dir = "${path.module}/.."
  }
}

resource "null_resource" "vagrant_wait_ready" {
  depends_on = [null_resource.vagrant_up]
  provisioner "local-exec" {
    command     = "bash scripts/vagrant-wait-ready.sh ${local.rancher_server_name} ${local.k8s_control_name} ${local.k8s_worker_name}"
    working_dir = "${path.module}/.."
  }
}

resource "null_resource" "install_rancher" {
  depends_on = [null_resource.vagrant_wait_ready]
  provisioner "local-exec" {
    command     = "bash scripts/install-rancher.sh ${var.versions.rancher} ${local.rancher_server_ip}"
    working_dir = "${path.module}/.."
  }
}

resource "null_resource" "rancher_ready" {
  depends_on = [null_resource.install_rancher]
  provisioner "local-exec" {
    command     = "bash scripts/wait-rancher-ready.sh https://${local.rancher_server_ip}"
    working_dir = "${path.module}/.."
  }
}
