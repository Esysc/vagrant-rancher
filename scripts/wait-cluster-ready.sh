#!/bin/bash
set -e

RANCHER_URL="$1"
RANCHER_TOKEN="$2"
CLUSTER_ID="$3"

echo "⏳ Waiting for cluster to be active..."

# Wait up to 20 minutes (240 iterations * 5 seconds)
for i in {1..240}; do
  # Use v1 API for cluster v2 (format: fleet-default/demo-cluster)
  CLUSTER_DATA=$(curl -sk -H "Authorization: Bearer $RANCHER_TOKEN" \
    "$RANCHER_URL/v1/provisioning.cattle.io.clusters/$CLUSTER_ID" 2>/dev/null)

  STATUS=$(echo "$CLUSTER_DATA" | jq -r '.status.ready // "unknown"')

  # Check if cluster is ready (status.ready = true)
  if [ "$STATUS" = "true" ]; then
    echo "✅ Cluster is active and ready!"
    exit 0
  fi

  # Get conditions for more detailed status
  CONDITIONS=$(echo "$CLUSTER_DATA" | jq -r '.status.conditions[] | select(.type=="Ready") | "\(.status) - \(.message)"' 2>/dev/null || echo "")

  # Show progress every 6 iterations (30 seconds)
  if [ $((i % 6)) -eq 0 ]; then
    MINUTES=$((i / 12))
    echo "⏳ Waiting for cluster ($MINUTES min) - Ready: $STATUS"
    if [ -n "$CONDITIONS" ]; then
      echo "   └─ $CONDITIONS"
    fi
  fi

  sleep 5
done

echo "❌ Cluster did not become ready after 20 minutes"
echo "   Final ready status: $STATUS"
exit 1
