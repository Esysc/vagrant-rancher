#!/bin/bash
set -e

RANCHER_VERSION="${1:-v2.13.1}"
RANCHER_IP="${2}"

if [ -z "$RANCHER_IP" ]; then
  echo "❌ Usage: $0 <rancher_version> <rancher_ip>"
  exit 1
fi

echo "🔍 Checking Rancher container status (version: $RANCHER_VERSION, IP: $RANCHER_IP)..."

# Check if container exists
if vagrant ssh rancher-server -c "docker ps -a --format '{{.Names}}' | grep -q '^rancher$'" 2>/dev/null; then
  echo "📦 Rancher container exists - checking state..."

  # Check if it's running and healthy
  CONTAINER_STATUS=$(vagrant ssh rancher-server -c "docker inspect rancher --format='{{.State.Status}}'" 2>/dev/null || echo "unknown")

  if [ "$CONTAINER_STATUS" = "running" ]; then
    # Check if it's actually healthy by testing the API
    if curl -skf "https://${RANCHER_IP}/ping" 2>/dev/null; then
      echo "✅ Rancher container is running and healthy"
      exit 0
    else
      echo "⚠️  Rancher container running but unhealthy - will recreate"
    fi
  else
    echo "⚠️  Rancher container not running (status: $CONTAINER_STATUS)"
  fi

  echo "🗑️  Removing existing Rancher container and volume..."
  vagrant ssh rancher-server -c "docker rm -f rancher 2>/dev/null || true"
  vagrant ssh rancher-server -c "docker volume rm rancher 2>/dev/null || true"
  echo "✅ Cleaned up old Rancher installation"
fi

echo "📥 Installing fresh Rancher container..."
vagrant ssh rancher-server -c "docker run -d \
  --restart=unless-stopped \
  --privileged \
  -p 80:80 \
  -p 443:443 \
  -v rancher:/var/lib/rancher \
  -e CATTLE_BOOTSTRAP_PASSWORD=admin_initial_password \
  --name rancher \
  rancher/rancher:$RANCHER_VERSION"
echo "✅ Rancher container installed"
