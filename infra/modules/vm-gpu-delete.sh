#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Deleting GPU VM: ${VM_GPU_NAME}"

az vm delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_GPU_NAME" \
  --yes \
  --force-deletion true \
  --output none 2>/dev/null || true

# Clean up associated resources
VM_NIC="${VM_GPU_NAME}VMNic"
VM_DISK="${VM_GPU_NAME}_OsDisk_1"
VM_IP_NAME="${VM_GPU_NAME}PublicIP"

az network nic delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NIC" \
  --output none 2>/dev/null || true

az disk delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_DISK" \
  --yes \
  --output none 2>/dev/null || true

az network public-ip delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_IP_NAME" \
  --output none 2>/dev/null || true

echo ">>> GPU VM ${VM_GPU_NAME} and associated resources deleted"
