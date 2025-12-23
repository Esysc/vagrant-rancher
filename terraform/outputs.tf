output "rancher_admin_password" {
  value     = local.rancher_admin_password
  sensitive = true
}

output "rancher_url" {
  value = "https://${local.rancher_server_ip}"
}

output "cluster_id" {
  value = rancher2_cluster_v2.demo.id
}

output "cluster_name" {
  value = rancher2_cluster_v2.demo.name
}

output "app_url" {
  value = "https://${local.k8s_control_ip}:30443 (or https://${local.k8s_worker_ip}:30443)"
}

output "kubeconfig_path" {
  value = "${path.module}/../kubeconfig-demo-cluster"
}
