# Rancher Kubernetes PoC

<img width="1784" height="570" alt="image" src="https://github.com/user-attachments/assets/e01b0b42-a194-4da1-a661-4369b3bd9920" />


This repository provides a proof-of-concept (PoC) for deploying a production-ready Kubernetes cluster using Vagrant, Terraform/OpenTofu, and Rancher. The deployment includes a full-stack train routing application demonstrating real-world microservices architecture.

## Repository Structure

- **Vagrantfile**: Vagrant configuration with IPv6 disabled for consistent networking.
- **vagrant.yaml**: VM specifications (memory, CPUs, IP addresses).
- **manifests/train-app.yaml**: Kubernetes manifests for the train routing application.
- **scripts/**: Automation scripts for setup and verification.
  - `provision.sh`: Installs Docker, kubectl, Helm, and chrony (time sync).
  - `install-rancher.sh`: Deploys Rancher server with specific version.
  - `wait-rancher-ready.sh`: Validates Rancher webhook stability.
  - `register-nodes.sh`: Registers nodes to Rancher cluster with SSL workarounds.
  - `wait-cluster-ready.sh`: Monitors cluster until active (up to 20 minutes).
  - `verify-app.sh`: Validates train application deployment.
- **terraform/**: Infrastructure as Code with OpenTofu/Terraform.
  - `main.tf`: Provider configuration and bootstrapping.
  - `variables.tf`: Centralized version management for Rancher and Kubernetes.
  - `rancher.tf`: Rancher installation and VM lifecycle management.
  - `cluster.tf`: RKE2 cluster provisioning and node registration.
  - `app.tf`: Train application deployment via kubectl.
  - `outputs.tf`: Credentials and access URLs.

## Architecture

### Infrastructure
- **rancher-server** (192.168.56.10): Rancher v2.13.1 in Docker container
- **k8s-control** (192.168.56.11): RKE2 control plane + etcd + worker (4GB RAM, 2 CPUs)
- **k8s-worker** (192.168.56.12): RKE2 worker node (4GB RAM, 2 CPUs)

### Application Stack
The deployed application is a full-stack train routing system with:

- **PostgreSQL 16**: Persistent database with StatefulSet
- **Symfony Backend** (PHP): REST API with 2 replicas
- **Vue3 Frontend** (TypeScript): SPA with 2 replicas
- **Nginx Gateway**: Reverse proxy with 2 replicas
- **NodePort Service**: Exposed on ports 30080 (HTTP) and 30443 (HTTPS)

All components use container images from `ghcr.io/esysc/defi-fullstack/*`.

**Application Source**: This is a sample train routing application. For more details, visit the [GitHub repository](https://github.com/Esysc/frontend-backend).

### Key Technologies
- **Kubernetes Distribution**: RKE2 v1.33.7+rke2r1
- **CNI**: Calico for pod networking
- **Time Synchronization**: Chrony (UTC) to prevent certificate issues
- **Networking**: IPv4 only (IPv6 disabled at OS and VirtualBox levels)

## Usage

### Prerequisites
- [Vagrant](https://www.vagrantup.com/) 2.2+
- [OpenTofu](https://opentofu.org/) 1.6+ or [Terraform](https://www.terraform.io/) 1.5+
- [VirtualBox](https://www.virtualbox.org/) 7.0+

### Quick Start

1. **Clone the repository:**
   ```sh
   git clone https://github.com/Esysc/vagrant-rancher.git
   cd rancher-kubernetes-poc
   ```

2. **Deploy the entire stack:**
   ```sh
   cd terraform
   tofu init
   tofu apply -auto-approve
   ```
   This automated process will:
   - Provision 3 VMs with IPv6 disabled
   - Install Docker, kubectl, Helm, and chrony on all nodes
   - Deploy Rancher v2.13.1 on rancher-server
   - Wait for Rancher webhook to stabilize
   - Create RKE2 v1.33.7+rke2r1 cluster in Rancher
   - Register k8s-control (control plane + etcd + worker) and k8s-worker
   - Wait up to 20 minutes for cluster to become active
   - Deploy the train routing application
   - Verify all components are running

   **Expected duration**: 15-25 minutes depending on network speed.

3. **Get access credentials:**
   ```sh
   cd terraform
   tofu output rancher_admin_password
   ```

4. **Access the services:**
   - **Rancher UI**: https://192.168.56.10 (username: `admin`, password from output)
     - **Note**: SSL certificate is self-signed. Your browser will show a security warning - accept it to proceed.
   - **Train App**: https://192.168.56.11:30443 or https://192.168.56.12:30443
     - **Note**: SSL certificate is self-signed. Your browser will show a security warning - accept it to proceed.

5. **Clean up everything:**
   ```sh
   cd terraform
   tofu destroy -auto-approve
   ```
   This will destroy the Rancher cluster resources, then tear down all VMs in the correct order.

## Train Routing Application

### Overview
The deployed application is a microservices-based train routing system that demonstrates a production-like architecture with multiple components communicating through an API gateway.

### Architecture

```
User → Nginx Gateway → [Frontend (Vue3) | Backend API (Symfony)] → PostgreSQL
```

### Components

| Component | Technology | Replicas | Purpose |
|-----------|-----------|----------|---------|
| PostgreSQL | PostgreSQL 16 | 1 (StatefulSet) | Persistent data storage |
| Backend API | Symfony/PHP | 2 | REST API for train route calculations |
| Frontend | Vue3/TypeScript | 2 | Single-page application UI |
| Gateway | Nginx | 2 | Reverse proxy and load balancer |

### Container Images
All images are sourced from GitHub Container Registry:
- `ghcr.io/esysc/defi-fullstack/postgres:latest`
- `ghcr.io/esysc/defi-fullstack/backend:latest`
- `ghcr.io/esysc/defi-fullstack/frontend:latest`
- `ghcr.io/esysc/defi-fullstack/nginx:latest`

### Access
The application is exposed via NodePort service on port **30443** (HTTPS):
- https://192.168.56.11:30443 (via control plane node)
- https://192.168.56.12:30443 (via worker node)

**Note**: The SSL certificate is self-signed. Your browser will show a security warning - accept it to proceed.

### Deployment Verification
The `verify-app.sh` script checks:
- ✅ PostgreSQL StatefulSet is ready (1/1)
- ✅ Backend Deployment is ready (2/2)
- ✅ Frontend Deployment is ready (2/2)
- ✅ Nginx Gateway Deployment is ready (2/2)
- ✅ All pods are in Running state

## Version Management

Versions are centrally managed in `terraform/variables.tf`:

```hcl
variable "versions" {
  type = object({
    rancher    = string
    kubernetes = string
  })
  default = {
    rancher    = "v2.13.1"
    kubernetes = "v1.33.7+rke2r1"
  }
}
```

**Version Compatibility**: Rancher v2.13.1 supports RKE2 v1.32.x through v1.34.x. Current configuration uses tested stable versions.

## Key Features

- ✅ **Fully Automated**: Zero-touch deployment from VMs to running application
- ✅ **Production Patterns**: StatefulSets, multi-replica deployments, persistent storage
- ✅ **Rancher-Managed**: Complete Kubernetes lifecycle managed by Rancher
- ✅ **SSL Handling**: Self-signed certificate workarounds for automated registration
- ✅ **Robust Validation**: Webhook stability checks, cluster readiness monitoring
- ✅ **Time Synchronization**: Chrony configured to prevent certificate timing issues
- ✅ **IPv4 Only**: IPv6 disabled to ensure consistent networking
- ✅ **Clean Teardown**: Proper dependency ordering with `terraform destroy`
- ✅ **Version Control**: Centralized version management for easy updates

## Customization

### VM Resources
Edit `vagrant.yaml` to adjust memory, CPUs, or IP addresses:
```yaml
vm:
  - name: rancher-server
    ip: 192.168.56.10
    memory: 4096  # 4GB
    cpus: 2
```

### Kubernetes and Rancher Versions
Edit `terraform/variables.tf`:
```hcl
default = {
  rancher    = "v2.13.1"          # Rancher Docker image tag
  kubernetes = "v1.33.7+rke2r1"   # RKE2 version (must include +rke2r1 suffix)
}
```

**Important**: Verify version compatibility in [Rancher's support matrix](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-13-1/) before changing.

### Deploy Different Application
Replace `manifests/train-app.yaml` with your own Kubernetes manifests, or modify `terraform/app.tf` to deploy using Helm charts instead of kubectl.

## Troubleshooting

### Worker node stuck on "waiting for probes: calico, kubelet"

**Symptoms:** Worker node shows as "Reconciling" in Rancher UI for extended period.

**Cause:** IPv6 address being used instead of IPv4, causing connectivity issues.

**Solution:** This is fixed in the current Vagrantfile (IPv6 disabled). If you encounter this:
```bash
# Check if worker can reach control plane
vagrant ssh k8s-worker -c "ping -c 3 192.168.56.11"

# Check RKE2 agent logs
vagrant ssh k8s-worker -c "sudo journalctl -u rke2-agent -n 50"

# Verify IPv6 is disabled
vagrant ssh k8s-worker -c "cat /proc/sys/net/ipv6/conf/all/disable_ipv6"  # Should be 1
```

### Terraform/OpenTofu hangs during apply

**Symptoms:** Terraform hangs while refreshing state or waiting for resources.

**Cause:** Terraform tries to connect to Rancher to refresh provider state, but Rancher isn't responding.

**Solutions:**

1. **Check if Rancher is running:**
   ```bash
   vagrant ssh rancher-server -c "docker ps | grep rancher"
   curl -sk https://192.168.56.10/ping
   ```

2. **If Rancher is down, restart it:**
   ```bash
   vagrant ssh rancher-server -c "docker start rancher"
   # Wait 30-60 seconds for initialization
   curl -sk https://192.168.56.10/ping
   ```

3. **Skip state refresh:**
   ```bash
   cd terraform
   tofu apply -refresh=false
   ```

### Cluster takes longer than 20 minutes

**Symptoms:** `wait-cluster-ready.sh` times out after 20 minutes.

**Cause:** Slow network, resource constraints, or image pull issues.

**Solutions:**

1. **Check cluster status in Rancher UI:**
   - Visit https://192.168.56.10
   - Navigate to Cluster Management → demo-cluster
   - Check "Provisioning Log" tab for detailed progress

2. **Check node resources:**
   ```bash
   vagrant ssh k8s-control -c "free -h && df -h"
   ```

3. **Monitor RKE2 installation:**
   ```bash
   vagrant ssh k8s-control -c "sudo journalctl -u rke2-server -f"
   ```

4. **Increase timeout** in `scripts/wait-cluster-ready.sh` (line 10):
   ```bash
   for i in {1..360}; do  # Increase from 240 to 360 (30 minutes)
   ```

### Registration token not generated

**Symptoms:** `register-nodes.sh` waits for registration token but times out.

**Cause:** Rancher cluster object created but token generation delayed.

**Solutions:**

1. **Wait longer** - Token generation can take 1-2 minutes after cluster creation

2. **Check Rancher logs:**
   ```bash
   vagrant ssh rancher-server -c "docker logs rancher --tail 50"
   ```

3. **Verify cluster exists:**
   ```bash
   curl -sk -H "Authorization: Bearer $(cd terraform && tofu output -raw rancher_token)" \
     https://192.168.56.10/v3/clusters | jq -r '.data[].name'
   ```

### Time synchronization issues

**Symptoms:** Certificate validation errors, SSL handshake failures.

**Cause:** VM clocks out of sync causing certificate timing problems.

**Solutions:**

1. **Verify chrony is running:**
   ```bash
   vagrant ssh k8s-control -c "sudo systemctl status chrony"
   ```

2. **Check time sync status:**
   ```bash
   vagrant ssh k8s-control -c "timedatectl"
   ```

3. **Manually sync time:**
   ```bash
   vagrant ssh k8s-control -c "sudo chronyc -a makestep"
   ```

### Nodes not appearing in Rancher

**Symptoms:** Registration script completes but nodes don't show up in Rancher UI.

**Solutions:**

1. **Check rancher-system-agent logs:**
   ```bash
   vagrant ssh k8s-control -c "sudo journalctl -u rancher-system-agent -n 50"
   vagrant ssh k8s-worker -c "sudo journalctl -u rancher-system-agent -n 50"
   ```

2. **Verify agent is running:**
   ```bash
   vagrant ssh k8s-control -c "sudo systemctl status rancher-system-agent"
   ```

3. **Check connectivity to Rancher:**
   ```bash
   vagrant ssh k8s-control -c "curl -sk https://192.168.56.10/ping"
   ```

### Application deployment fails

**Symptoms:** Train app pods not running or in CrashLoopBackOff.

**Solutions:**

1. **Check pod status:**
   ```bash
   vagrant ssh k8s-control -c "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml get pods -n default"
   ```

2. **Check pod logs:**
   ```bash
   vagrant ssh k8s-control -c "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml logs -n default <pod-name>"
   ```

3. **Verify images are pullable:**
   ```bash
   vagrant ssh k8s-worker -c "sudo crictl pull ghcr.io/esysc/defi-fullstack/frontend:latest"
   ```

4. **Re-deploy the application:**
   ```bash
   cd terraform
   tofu taint null_resource.deploy_app
   tofu apply -target=null_resource.deploy_app
   ```

### Clean slate (complete reset)

If nothing else works, destroy everything and redeploy:

```bash
cd terraform
tofu destroy -auto-approve
vagrant destroy -f
vagrant up
tofu apply -auto-approve
```

### Useful diagnostic commands

**Check all VM status:**
```bash
vagrant status
```

**SSH into VMs:**
```bash
vagrant ssh rancher-server
vagrant ssh k8s-control
vagrant ssh k8s-worker
```

**Check cluster resources:**
```bash
vagrant ssh k8s-control -c "sudo /var/lib/rancher/rke2/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml get nodes,pods -A"
```

**Monitor real-time logs:**
```bash
vagrant ssh k8s-control -c "sudo journalctl -u rke2-server -f"
```

**Check VM resources:**
```bash
vagrant ssh k8s-control -c "free -h && df -h && uptime"
```

## Implementation Notes

### SSL Certificate Handling
Self-signed certificates from Rancher are handled by adding `-k` flag to curl commands in the registration script. This is suitable for PoC/development but should use proper certificates in production.

### Destroy Order
Terraform manages destroy order through dependencies. The `vagrant destroy` command is executed via a destroy provisioner on the `vagrant_up` resource, ensuring Rancher resources are cleaned up before VMs are destroyed.

### Webhook Validation
The `wait-rancher-ready.sh` script monitors webhook pod logs for stability (5 consecutive successful checks over 15 seconds) rather than using simple delays, ensuring Rancher is truly ready before proceeding.

## License

This project is for demonstration purposes. Use at your own risk.
