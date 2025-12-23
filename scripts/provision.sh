#!/bin/bash
set -euo pipefail

echo "Updating package lists..."
apt-get update

echo "Setting timezone to UTC and installing time sync..."
timedatectl set-timezone UTC
apt-get install -y chrony
systemctl enable chrony
systemctl start chrony

echo "Installing Docker, curl, wget, gnupg, and jq..."
apt-get install -y docker.io curl wget gnupg jq

echo "Enabling and starting Docker service..."
systemctl enable docker
systemctl start docker

echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "Installing Helm..."
curl -fsSL https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz | tar -xzC /usr/local/bin --strip-components=1 linux-amd64/helm

echo "Adding $USER and vagrant to docker group..."
usermod -aG docker "$USER"
usermod -aG docker vagrant

echo "Configuring RKE2 to use private network IP..."
PRIVATE_IP=$(ip -4 addr show eth1 | grep inet | awk '{print $2}' | cut -d'/' -f1)
if [ -n "$PRIVATE_IP" ]; then
  mkdir -p /etc/rancher/rke2
  echo "node-ip: $PRIVATE_IP" >/etc/rancher/rke2/config.yaml
  chmod 600 /etc/rancher/rke2/config.yaml
  echo "RKE2 will use IP: $PRIVATE_IP"
fi

echo "✅ Provisioning complete! Docker group changes will apply to new SSH sessions."
