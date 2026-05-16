#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# doc-intelligence-delete.sh — Stop disconnected container and delete
#                               commitment resource
#
# 1. SSH to VM and stop/remove the doc-intel container
# 2. Delete the Azure Cognitive Services commitment resource
# Idempotent: safe to re-run
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-RAG-AI-Infra}.env"

echo ">>> Stopping Document Intelligence container on VM: ${VM_NAME}"

VM_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --show-details \
  --query publicIps --output tsv 2>/dev/null || echo "")

if [[ -n "$VM_IP" ]]; then
  ssh -o StrictHostKeyChecking=no azureuser@"$VM_IP" \
    "docker rm -f doc-intel 2>/dev/null || true" 2>/dev/null || true
  echo ">>> Container stopped"
else
  echo ">>> VM not found or no public IP — skipping container cleanup"
fi

echo ">>> Deleting Document Intelligence commitment resource: ${DOC_INTEL_NAME}"

az cognitiveservices account delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DOC_INTEL_NAME" \
  --output none 2>/dev/null || true

az cognitiveservices account purge \
  --location "$LOCATION" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DOC_INTEL_NAME" \
  --output none 2>/dev/null || true

# Remove key from Key Vault
az keyvault secret delete \
  --vault-name "$KEYVAULT_NAME" \
  --name "doc-intel-key" \
  --output none 2>/dev/null || true

echo ">>> Document Intelligence ${DOC_INTEL_NAME} deleted"
