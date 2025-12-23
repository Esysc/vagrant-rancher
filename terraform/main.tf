terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
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

  # Extract VM names and IPs
  vms = { for vm in local.vagrant_config.vm : vm.name => vm.ip }

  # VM references
  rancher_server_ip   = local.vms["rancher-server"]
  rancher_server_name = "rancher-server"
  k8s_control_ip      = local.vms["k8s-control"]
  k8s_control_name    = "k8s-control"
  k8s_worker_ip       = local.vms["k8s-worker"]
  k8s_worker_name     = "k8s-worker"
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
