#!/bin/bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <vm_name1> [vm_name2] [vm_name3] ..."
  exit 1
fi

VM_NAMES=("$@")

wait_for_vm() {
  local vm="$1"
  echo "Waiting for $vm to be running and accessible..."
  for i in {1..30}; do
    vagrant status "$vm" | grep -q "running" &&
      vagrant ssh "$vm" -c "echo VM $vm is up" >/dev/null 2>&1 && {
      echo "$vm is up!"
      return 0
    }
    echo "  $vm not ready yet ($i)..."
    sleep 10
  done
  echo "Timed out waiting for $vm"
  return 1
}

for vm in "${VM_NAMES[@]}"; do
  echo "Checking VM: '$vm'"
  [ -z "$vm" ] && continue
  wait_for_vm "$vm" &
done
wait
