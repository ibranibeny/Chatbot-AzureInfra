#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-RAG-AI-Infra}.env"

echo ">>> Deleting VNet: ${VNET_NAME}"

# Remove NSGs first
az network nsg delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NSG" \
  --output none 2>/dev/null || true

az network nsg delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_GPU_NSG" \
  --output none 2>/dev/null || true

az network vnet delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --output none 2>/dev/null || true

echo ">>> VNet ${VNET_NAME} deleted"
