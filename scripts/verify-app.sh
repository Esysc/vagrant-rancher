#!/bin/bash
set -e

K8S_CONTROL_IP="$1"
K8S_WORKER_IP="$2"

if [ -z "$K8S_CONTROL_IP" ] || [ -z "$K8S_WORKER_IP" ]; then
  echo "❌ Usage: $0 <control_ip> <worker_ip>"
  exit 1
fi

echo "⏳ Waiting for train app to be ready..."

# Get kubeconfig from control node
mkdir -p /tmp/demo-cluster
vagrant ssh k8s-control -c 'sudo cat /etc/rancher/rke2/rke2.yaml' |
  sed "s|127.0.0.1|${K8S_CONTROL_IP}|g" >/tmp/demo-cluster/kubeconfig.yaml

export KUBECONFIG=/tmp/demo-cluster/kubeconfig.yaml

# Wait for database to be ready first
echo "⏳ Waiting for PostgreSQL..."
for i in {1..30}; do
  DB_READY=$(kubectl get pods -n train-app -l app=postgres -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l)
  if [ "$DB_READY" -eq 1 ]; then
    echo "✅ PostgreSQL is ready!"
    break
  fi
  echo "⏳ Waiting for PostgreSQL... ($i/30)"
  sleep 5
done

# Wait for all app pods
echo "⏳ Waiting for application pods..."
for i in {1..60}; do
  BACKEND_READY=$(kubectl get pods -n train-app -l app=backend -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l)
  FRONTEND_READY=$(kubectl get pods -n train-app -l app=frontend -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l)
  NGINX_READY=$(kubectl get pods -n train-app -l app=nginx -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l)

  if [ "$BACKEND_READY" -eq 2 ] && [ "$FRONTEND_READY" -eq 2 ] && [ "$NGINX_READY" -eq 2 ]; then
    echo "✅ All train app pods are ready!"
    kubectl get pods -n train-app
    echo ""
    echo "🌐 Access the Train Routing App at: http://${K8S_CONTROL_IP}:30080"
    echo "🌐 Or at: http://${K8S_WORKER_IP}:30080"
    echo ""
    echo "📝 Features:"
    echo "   - Frontend: Vue 3 + TypeScript + Vuetify"
    echo "   - Backend: Symfony 7 (PHP) with REST API"
    echo "   - Database: PostgreSQL"
    echo "   - Auth: JWT-based authentication"
    echo "   - Demo: Train routing with Dijkstra algorithm"
    exit 0
  fi
  echo "⏳ Waiting for pods... ($i/60) - Backend: $BACKEND_READY/2, Frontend: $FRONTEND_READY/2, Nginx: $NGINX_READY/2"
  sleep 5
done

echo "❌ Train app pods did not become ready after 5 minutes"
kubectl get pods -n train-app
exit 1
