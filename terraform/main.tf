terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = ">= 4.0.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 3.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
    null   = { source = "hashicorp/null" }
    local  = { source = "hashicorp/local" }
    random = { source = "hashicorp/random" }
  }
}

locals {
  # Read VM configurations from vagrant.yaml
  vagrant_config = yamldecode(file("${path.module}/../vagrant.yaml"))

  # Box name
  box_name = local.vagrant_config.box_name

  # VM list (preserves order from YAML)
  vms = local.vagrant_config.vm

  # VM references - access by index to preserve YAML order
  rancher_server_name = local.vms[0].name
  rancher_server_ip   = local.vms[0].ip
  k8s_control_name    = local.vms[1].name
  k8s_control_ip      = local.vms[1].ip
  k8s_worker_name     = local.vms[2].name
  k8s_worker_ip       = local.vms[2].ip
}

provider "rancher2" {
  api_url   = "https://${local.rancher_server_ip}"
  bootstrap = true
  insecure  = true
}

resource "rancher2_bootstrap" "admin" {
  initial_password = "admin_initial_password"
  password         = local.rancher_admin_password
  depends_on       = [null_resource.rancher_ready]
}
provider "rancher2" {
  alias     = "admin"
  api_url   = "https://${local.rancher_server_ip}"
  insecure  = true
  token_key = rancher2_bootstrap.admin.token
}
resource "random_password" "rancher_admin" {
  length  = 16
  special = true
}

locals {
  rancher_admin_password = random_password.rancher_admin.result
}

resource "random_integer" "nodeport" {
  min = 0
  max = 9
}
