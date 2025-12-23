#!/bin/bash
set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: $0 <vm_name1> [vm_name2] [vm_name3] ..."
  exit 1
fi

VM_NAMES=("$@")

echo "Starting VMs in parallel..."
for vm in "${VM_NAMES[@]}"; do
  echo "$vm"
done | xargs -P3 -I {} vagrant up {}
echo "All vagrant up commands finished."
