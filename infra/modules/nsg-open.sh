#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# nsg-open.sh — Open all NSG rules to allow internet access (workshop/demo)
#
# WARNING: This opens ALL service ports to the internet. Use only for
#          workshops, demos, or testing. NEVER use in production.
#
# Usage:
#   ENV_NAME=dev bash modules/nsg-open.sh        # open all ports
#   ENV_NAME=dev bash modules/nsg-open.sh close   # restore VNet-only rules
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

ACTION="${1:-open}"

if [[ "$ACTION" == "open" ]]; then
  echo "============================================================"
  echo "  WARNING: Opening all service ports to the internet"
  echo "  Resource Group: ${RESOURCE_GROUP}"
  echo "============================================================"
  echo ""

  # --- SSH access for both VMs ---
  echo ">>> Opening SSH (22) on ${VM_NSG}"
  az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes "*" \
    --destination-port-ranges 22 \
    --access Allow --protocol Tcp --output none 2>/dev/null || \
  az network nsg rule update \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name AllowSSH \
    --source-address-prefixes "*" \
    --output none

  echo ">>> Opening SSH (22) on ${VM_GPU_NSG}"
  az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_GPU_NSG" \
    --name AllowSSH \
    --priority 100 \
    --source-address-prefixes "*" \
    --destination-port-ranges 22 \
    --access Allow --protocol Tcp --output none 2>/dev/null || \
  az network nsg rule update \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_GPU_NSG" \
    --name AllowSSH \
    --source-address-prefixes "*" \
    --output none

  # --- Qdrant VM NSG ---
  echo ">>> Opening Qdrant ports (6333, 6334) on ${VM_NSG}"
  az network nsg rule update \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name AllowQdrantFromVNet \
    --source-address-prefixes "*" \
    --output none 2>/dev/null || \
  az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name AllowQdrantFromVNet \
    --priority 200 \
    --source-address-prefixes "*" \
    --destination-port-ranges 6333 6334 \
    --access Allow --protocol Tcp --output none

  echo ">>> Removing DenyQdrantFromInternet rule on ${VM_NSG}"
  az network nsg rule delete \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name DenyQdrantFromInternet \
    --output none 2>/dev/null || true

  echo ">>> Opening Doc Intelligence port (${DOC_INTEL_PORT}) on ${VM_NSG}"
  az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name AllowDocIntelFromInternet \
    --priority 250 \
    --source-address-prefixes "*" \
    --destination-port-ranges "${DOC_INTEL_PORT}" \
    --access Allow --protocol Tcp --output none 2>/dev/null || \
  az network nsg rule update \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name AllowDocIntelFromInternet \
    --source-address-prefixes "*" \
    --output none

  # --- GPU VM NSG ---
  echo ">>> Opening vLLM port (${VLLM_PORT}) on ${VM_GPU_NSG}"
  az network nsg rule update \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_GPU_NSG" \
    --name AllowVLLMFromVNet \
    --source-address-prefixes "*" \
    --output none 2>/dev/null || \
  az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_GPU_NSG" \
    --name AllowVLLMFromVNet \
    --priority 200 \
    --source-address-prefixes "*" \
    --destination-port-ranges "${VLLM_PORT}" \
    --access Allow --protocol Tcp --output none

  echo ">>> Removing DenyVLLMFromInternet rule on ${VM_GPU_NSG}"
  az network nsg rule delete \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_GPU_NSG" \
    --name DenyVLLMFromInternet \
    --output none 2>/dev/null || true

  echo ""
  echo ">>> All service ports now open to the internet"
  echo ">>> SSH:     22 (VMs: ${VM_NAME}, ${VM_GPU_NAME})"
  echo ">>> Qdrant:  6333, 6334 (VM: ${VM_NAME})"
  echo ">>> DocIntel: ${DOC_INTEL_PORT} (VM: ${VM_NAME})"
  echo ">>> vLLM:    ${VLLM_PORT} (VM: ${VM_GPU_NAME})"

elif [[ "$ACTION" == "close" ]]; then
  echo "============================================================"
  echo "  Restoring NSG rules to VNet-only access"
  echo "  Resource Group: ${RESOURCE_GROUP}"
  echo "============================================================"
  echo ""

  # --- Remove SSH access ---
  echo ">>> Removing SSH access on ${VM_NSG}"
  az network nsg rule delete \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name AllowSSH \
    --output none 2>/dev/null || true

  echo ">>> Removing SSH access on ${VM_GPU_NSG}"
  az network nsg rule delete \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_GPU_NSG" \
    --name AllowSSH \
    --output none 2>/dev/null || true

  # --- Qdrant VM NSG ---
  echo ">>> Restricting Qdrant ports to VNet only on ${VM_NSG}"
  az network nsg rule update \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name AllowQdrantFromVNet \
    --source-address-prefixes VirtualNetwork \
    --output none

  echo ">>> Re-adding DenyQdrantFromInternet rule on ${VM_NSG}"
  az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name DenyQdrantFromInternet \
    --priority 300 \
    --source-address-prefixes Internet \
    --destination-port-ranges 6333 6334 \
    --access Deny --protocol Tcp --output none 2>/dev/null || true

  echo ">>> Removing AllowDocIntelFromInternet rule on ${VM_NSG}"
  az network nsg rule delete \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_NSG" \
    --name AllowDocIntelFromInternet \
    --output none 2>/dev/null || true

  # --- GPU VM NSG ---
  echo ">>> Restricting vLLM port to VNet only on ${VM_GPU_NSG}"
  az network nsg rule update \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_GPU_NSG" \
    --name AllowVLLMFromVNet \
    --source-address-prefixes VirtualNetwork \
    --output none

  echo ">>> Re-adding DenyVLLMFromInternet rule on ${VM_GPU_NSG}"
  az network nsg rule create \
    --resource-group "$RESOURCE_GROUP" \
    --nsg-name "$VM_GPU_NSG" \
    --name DenyVLLMFromInternet \
    --priority 300 \
    --source-address-prefixes Internet \
    --destination-port-ranges "${VLLM_PORT}" \
    --access Deny --protocol Tcp --output none 2>/dev/null || true

  echo ""
  echo ">>> NSG rules restored to VNet-only access"

else
  echo "Usage: bash modules/nsg-open.sh [open|close]"
  exit 1
fi
