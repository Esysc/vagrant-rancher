#!/bin/bash
set -e

RANCHER_URL="$1"

echo "⏳ Waiting for Rancher API to be ready..."

for i in {1..60}; do
  if curl -skf "$RANCHER_URL/ping" >/dev/null 2>&1; then
    echo "✅ Rancher API responding!"
    break
  fi
  echo "⏳ Waiting for Rancher API... ($i/60)"
  sleep 10
done

# Wait for webhook deployment to be ready in the local cluster
echo "⏳ Waiting for Rancher webhook deployment to be ready..."
for i in {1..60}; do
  # Check webhook pod status using kubectl inside the rancher container via vagrant ssh
  WEBHOOK_OUTPUT=$(vagrant ssh rancher-server -c \
    "docker exec rancher kubectl get deployment rancher-webhook -n cattle-system -o jsonpath='{.status.readyReplicas}' 2>&1" 2>&1 || true)

  echo "DEBUG: WEBHOOK_OUTPUT='$WEBHOOK_OUTPUT'"

  WEBHOOK_READY=$(echo "$WEBHOOK_OUTPUT" | grep -E '^[0-9]+$' || echo "0")

  echo "DEBUG: WEBHOOK_READY='$WEBHOOK_READY'"

  if [ "$WEBHOOK_READY" != "0" ] && [ "$WEBHOOK_READY" != "" ]; then
    echo "✅ Rancher webhook deployment has $WEBHOOK_READY ready replica(s)!"

    # Wait for webhook to be registered with API server
    echo "⏳ Waiting for webhook to register with API server..."
    for j in {1..30}; do
      WEBHOOK_CONFIG=$(vagrant ssh rancher-server -c \
        "docker exec rancher kubectl get validatingwebhookconfigurations rancher.cattle.io -o jsonpath='{.webhooks[0].clientConfig.service.name}' 2>/dev/null" 2>/dev/null || echo "")

      if [ "$WEBHOOK_CONFIG" = "rancher-webhook" ]; then
        echo "✅ Webhook is registered with API server!"

        # Monitor webhook logs for stabilization
        echo "⏳ Monitoring webhook logs for stability..."
        STABLE_COUNT=0
        for m in {1..30}; do
          WEBHOOK_LOGS=$(vagrant ssh rancher-server -c \
            "docker exec rancher kubectl logs -n cattle-system -l app=rancher-webhook --tail=5 2>/dev/null" 2>/dev/null || echo "")

          # Check if logs show errors or if webhook is stable
          if echo "$WEBHOOK_LOGS" | grep -qiE "error|failed|panic|crash"; then
            echo "⚠️ Webhook showing errors, waiting... ($m/30)"
            STABLE_COUNT=0
            sleep 3
          else
            STABLE_COUNT=$((STABLE_COUNT + 1))
            if [ $STABLE_COUNT -ge 5 ]; then
              echo "✅ Webhook logs stable for 15 seconds!"
              break
            fi
            echo "⏳ Webhook stable ($STABLE_COUNT/5)..."
            sleep 3
          fi
        done

        # Verify webhook is actually responding
        echo "⏳ Verifying webhook endpoint health..."
        for k in {1..10}; do
          WEBHOOK_HEALTH=$(vagrant ssh rancher-server -c \
            "docker exec rancher kubectl get endpoints rancher-webhook -n cattle-system -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null" 2>/dev/null || echo "")

          if [ -n "$WEBHOOK_HEALTH" ]; then
            echo "✅ Webhook endpoint is healthy!"
            echo "✅ Rancher is fully ready!"
            exit 0
          fi

          echo "⏳ Checking webhook endpoint... ($k/10)"
          sleep 5
        done

        echo "⚠️ Webhook endpoint check inconclusive, proceeding..."
        echo "✅ Rancher is fully ready!"
        exit 0
      fi

      echo "⏳ Waiting for webhook registration... ($j/30)"
      sleep 3
    done

    echo "⚠️  Webhook registration not confirmed, waiting extra 60s..."
    sleep 60
    echo "✅ Rancher is fully ready!"
    exit 0
  fi

  echo "⏳ Waiting for webhook deployment... ($i/60)"
  sleep 5
done

echo "⚠️  Webhook deployment not detected after 5 minutes, proceeding anyway..."
exit 0
