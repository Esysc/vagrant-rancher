# =============================================================================
# Vagrant VM Lifecycle - Must remain as null_resource (no Terraform provider)
# =============================================================================

resource "null_resource" "vagrant_up" {
  provisioner "local-exec" {
    command     = "bash scripts/vagrant-parallel-up.sh ${local.box_name} ${local.rancher_server_name} ${local.k8s_control_name} ${local.k8s_worker_name}"
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

# =============================================================================
# Docker Provider - Connects to rancher-server via SSH
# =============================================================================

provider "docker" {
  host = "ssh://vagrant@${local.rancher_server_ip}:22"
  ssh_opts = [
    "-o", "StrictHostKeyChecking=no",
    "-o", "UserKnownHostsFile=/dev/null",
    "-i", "${path.module}/../.vagrant/machines/${local.rancher_server_name}/virtualbox/private_key"
  ]
}

# =============================================================================
# Rancher Installation - Using Docker provider (declarative)
# =============================================================================

resource "docker_image" "rancher" {
  name = "rancher/rancher:${var.versions.rancher}"

  depends_on = [null_resource.vagrant_wait_ready]
}

resource "docker_volume" "rancher_data" {
  name = "rancher"

  depends_on = [null_resource.vagrant_wait_ready]
}

resource "docker_container" "rancher" {
  name       = "rancher"
  image      = docker_image.rancher.image_id
  restart    = "unless-stopped"
  privileged = true

  ports {
    internal = 80
    external = 80
  }

  ports {
    internal = 443
    external = 443
  }

  volumes {
    volume_name    = docker_volume.rancher_data.name
    container_path = "/var/lib/rancher"
  }

  env = [
    "CATTLE_BOOTSTRAP_PASSWORD=admin_initial_password"
  ]

  depends_on = [docker_image.rancher, docker_volume.rancher_data]
}

# Wait for Rancher API to be ready
resource "null_resource" "rancher_ready" {
  depends_on = [docker_container.rancher]
  provisioner "local-exec" {
    command     = "bash scripts/wait-rancher-ready.sh https://${local.rancher_server_ip}"
    working_dir = "${path.module}/.."
  }
}
