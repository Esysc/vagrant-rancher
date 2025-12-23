#!/bin/bash
set -e

CONTROL_IP="$1"
WORKER_IP="$2"

if [ -z "$CONTROL_IP" ] || [ -z "$WORKER_IP" ]; then
  echo "❌ Usage: $0 <control_ip> <worker_ip>"
  exit 1
fi

echo "🔐 Generating JWT key pair on k8s-control..."

# Generate keys directly on the VM and create secret
vagrant ssh k8s-control -c "
  set -e
  cd /tmp
  openssl genrsa -out private.pem 4096 2>/dev/null
  openssl rsa -in private.pem -pubout -out public.pem 2>/dev/null

  echo '📝 Creating namespace if not exists...'
  sudo kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml create namespace train-app --dry-run=client -o yaml | sudo kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml apply -f -

  echo '📝 Creating Kubernetes secret...'
  sudo kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml create secret generic jwt-keys \
    --from-file=private.pem=/tmp/private.pem \
    --from-file=public.pem=/tmp/public.pem \
    --namespace=train-app \
    --dry-run=client -o yaml | sudo kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml apply -f -

  rm -f /tmp/private.pem /tmp/public.pem
  echo '✅ JWT secret created successfully'
"
