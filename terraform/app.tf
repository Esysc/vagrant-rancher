resource "null_resource" "generate_jwt_keys" {
  depends_on = [null_resource.wait_cluster_ready]

  provisioner "local-exec" {
    command     = "bash scripts/generate-jwt-secret.sh ${local.k8s_control_ip} ${local.k8s_worker_ip}"
    working_dir = "${path.module}/.."
  }
}

resource "null_resource" "deploy_train_app" {
  depends_on = [null_resource.generate_jwt_keys]

  provisioner "local-exec" {
    command     = <<-EOT
      vagrant ssh k8s-control -c "sudo kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml apply -f /vagrant/manifests/train-app.yaml"
    EOT
    working_dir = "${path.module}/.."
  }

  provisioner "local-exec" {
    when        = destroy
    command     = <<-EOT
      vagrant ssh k8s-control -c "sudo kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml delete -f /vagrant/manifests/train-app.yaml" || true
    EOT
    working_dir = "${path.module}/.."
  }
}

resource "null_resource" "verify_app" {
  depends_on = [
    null_resource.deploy_train_app,
    null_resource.vagrant_wait_ready
  ]

  provisioner "local-exec" {
    command     = "bash scripts/verify-app.sh ${local.k8s_control_ip} ${local.k8s_worker_ip}"
    working_dir = "${path.module}/.."
  }
}
