#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <box_name> <vm_name1> [vm_name2] [vm_name3] ..."
  exit 1
fi

BOX_NAME="$1"
shift
VM_NAMES=("$@")

# Pre-download the box to avoid parallel download race conditions
echo "Ensuring box '$BOX_NAME' is downloaded..."
vagrant box add "$BOX_NAME" --provider virtualbox 2>/dev/null || true

echo "Starting VMs in parallel..."
for vm in "${VM_NAMES[@]}"; do
  echo "$vm"
done | xargs -P3 -I {} vagrant up {}
echo "All vagrant up commands finished."
