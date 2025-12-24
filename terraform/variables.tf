variable "versions" {
  description = "Versions for Rancher and Kubernetes"
  type = object({
    rancher    = string
    kubernetes = string
  })
  default = {
    rancher    = "v2.13.1"
    kubernetes = "v1.33.7+rke2r1"
  }
}
