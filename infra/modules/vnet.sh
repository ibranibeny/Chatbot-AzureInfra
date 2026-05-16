#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-RAG-AI-Infra}.env"

echo ">>> Creating VNet: ${VNET_NAME}"

az network vnet create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VNET_NAME" \
  --location "$LOCATION" \
  --address-prefix "$VNET_PREFIX" \
  --output none

echo ">>> Creating subnet: ${SUBNET_VM}"
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_VM" \
  --address-prefix "$SUBNET_VM_PREFIX" \
  --output none 2>/dev/null || true

echo ">>> Creating subnet: ${SUBNET_GPU}"
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_GPU" \
  --address-prefix "$SUBNET_GPU_PREFIX" \
  --output none 2>/dev/null || true

echo ">>> Creating subnet: ${SUBNET_APPS}"
az network vnet subnet create \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_APPS" \
  --address-prefix "$SUBNET_APPS_PREFIX" \
  --output none 2>/dev/null || true

# NSG for Qdrant VM
echo ">>> Creating NSG: ${VM_NSG}"
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NSG" \
  --location "$LOCATION" \
  --output none 2>/dev/null || true

az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$VM_NSG" \
  --name AllowSSH \
  --priority 100 \
  --source-address-prefixes Internet \
  --destination-port-ranges 22 \
  --access Allow --protocol Tcp --output none 2>/dev/null || true

az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$VM_NSG" \
  --name AllowQdrantFromVNet \
  --priority 200 \
  --source-address-prefixes VirtualNetwork \
  --destination-port-ranges 6333 6334 \
  --access Allow --protocol Tcp --output none 2>/dev/null || true

az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$VM_NSG" \
  --name DenyQdrantFromInternet \
  --priority 300 \
  --source-address-prefixes Internet \
  --destination-port-ranges 6333 6334 \
  --access Deny --protocol Tcp --output none 2>/dev/null || true

# NSG for GPU VM
echo ">>> Creating NSG: ${VM_GPU_NSG}"
az network nsg create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_GPU_NSG" \
  --location "$LOCATION" \
  --output none 2>/dev/null || true

az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$VM_GPU_NSG" \
  --name AllowSSH \
  --priority 100 \
  --source-address-prefixes Internet \
  --destination-port-ranges 22 \
  --access Allow --protocol Tcp --output none 2>/dev/null || true

az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$VM_GPU_NSG" \
  --name AllowVLLMFromVNet \
  --priority 200 \
  --source-address-prefixes VirtualNetwork \
  --destination-port-ranges 8000 \
  --access Allow --protocol Tcp --output none 2>/dev/null || true

az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "$VM_GPU_NSG" \
  --name DenyVLLMFromInternet \
  --priority 300 \
  --source-address-prefixes Internet \
  --destination-port-ranges 8000 \
  --access Deny --protocol Tcp --output none 2>/dev/null || true

# Associate NSGs with subnets
echo ">>> Associating NSGs with subnets"
az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_VM" \
  --network-security-group "$VM_NSG" \
  --output none

az network vnet subnet update \
  --resource-group "$RESOURCE_GROUP" \
  --vnet-name "$VNET_NAME" \
  --name "$SUBNET_GPU" \
  --network-security-group "$VM_GPU_NSG" \
  --output none

echo ">>> VNet ${VNET_NAME} with subnets and NSGs ready"
