#!/bin/bash
set -e

RANCHER_URL="$1"
RANCHER_TOKEN="$2"
CLUSTER_V1_ID="$3"
K8S_CONTROL_IP="$4"
K8S_WORKER_IP="$5"

if [ -z "$RANCHER_URL" ] || [ -z "$RANCHER_TOKEN" ] || [ -z "$CLUSTER_V1_ID" ] || [ -z "$K8S_CONTROL_IP" ] || [ -z "$K8S_WORKER_IP" ]; then
  echo "❌ Usage: $0 <rancher_url> <rancher_token> <cluster_v1_id> <control_ip> <worker_ip>"
  exit 1
fi

echo "📋 Using IPs:"
echo "   k8s-control: $K8S_CONTROL_IP"
echo "   k8s-worker: $K8S_WORKER_IP"

echo "⏳ Getting registration command for cluster: $CLUSTER_V1_ID"

# Sleep a bit to let cluster object settle
sleep 10

# Now get the registration token using the cluster ID
REG_CMD=""
for i in {1..40}; do
  # Try to get existing token
  TOKEN_RESPONSE=$(curl -sk -H "Authorization: Bearer $RANCHER_TOKEN" \
    "$RANCHER_URL/v3/clusterregistrationtoken?clusterId=$CLUSTER_V1_ID" 2>/dev/null || echo '{}')

  REG_CMD=$(echo "$TOKEN_RESPONSE" | jq -r '.data[0].nodeCommand // empty' 2>/dev/null || echo '')

  if [ -n "$REG_CMD" ]; then
    echo "✅ Got registration command"
    break
  fi

  if [ "$i" -eq 1 ]; then
    echo "DEBUG: Token response: $TOKEN_RESPONSE" | head -c 500
  fi

  echo "⏳ Waiting for registration token... ($i/40)"
  sleep 5
done

if [ -z "$REG_CMD" ]; then
  echo "❌ Failed to get registration command after 40 attempts"
  exit 1
fi

# Add -k flag to curl for self-signed certificates
REG_CMD=${REG_CMD//curl -fL/curl -fkL}
echo "Registration command prepared (with SSL verification disabled)"

echo "📝 Registering k8s-control as controlplane/etcd/worker..."
if ! vagrant ssh k8s-control -c "sudo $REG_CMD --etcd --controlplane --worker"; then
  echo "❌ Failed to register k8s-control node"
  exit 1
fi

echo "📝 Registering k8s-worker as worker..."
if ! vagrant ssh k8s-worker -c "sudo $REG_CMD --worker"; then
  echo "❌ Failed to register k8s-worker node"
  exit 1
fi

echo "✅ Node registration commands executed successfully"

# Verify the agent is actually running
echo "⏳ Verifying rancher-system-agent is running on nodes..."
sleep 5

REGISTRATION_FAILED=0
for node in k8s-control k8s-worker; do
  echo "Checking $node..."
  AGENT_STATUS=$(vagrant ssh $node -c "sudo systemctl is-active rancher-system-agent 2>/dev/null || echo 'not-found'")
  if [ "$AGENT_STATUS" = "active" ]; then
    echo "  ✅ rancher-system-agent is active on $node"
  else
    echo "  ❌ rancher-system-agent is not active on $node (status: $AGENT_STATUS)"
    echo "  📋 Checking logs..."
    vagrant ssh $node -c "sudo journalctl -u rancher-system-agent --no-pager -n 20 2>/dev/null || echo 'No logs available'"
    REGISTRATION_FAILED=1
  fi
done

if [ $REGISTRATION_FAILED -eq 1 ]; then
  echo "❌ Node registration verification failed"
  exit 1
fi

echo "✅ Node registration verification complete"
