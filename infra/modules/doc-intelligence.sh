#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# doc-intelligence.sh — Provision Azure Document Intelligence (cloud)
#
# Creates:
#   1. Azure Cognitive Services (FormRecognizer) S0 in southeastasia
#   2. Stores endpoint in Key Vault
#   3. Uses managed identity for auth (no API keys needed at runtime)
#
# Idempotent: safe to re-run
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-RAG-AI-Infra}.env"

echo ">>> Creating Document Intelligence (cloud): ${DOC_INTEL_NAME}"

# FormRecognizer is not available in indonesiacentral; use southeastasia
DOC_INTEL_LOCATION="${LOCATION_APPS}"
echo ">>> Using ${DOC_INTEL_LOCATION} for FormRecognizer resource"

az cognitiveservices account create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DOC_INTEL_NAME" \
  --location "$DOC_INTEL_LOCATION" \
  --kind FormRecognizer \
  --sku S0 \
  --custom-domain "$DOC_INTEL_NAME" \
  --output none 2>/dev/null || true

# Wait for provisioning
echo ">>> Waiting for ${DOC_INTEL_NAME} provisioning..."
for i in $(seq 1 30); do
  STATE=$(az cognitiveservices account show \
    --resource-group "$RESOURCE_GROUP" --name "$DOC_INTEL_NAME" \
    --query "properties.provisioningState" --output tsv 2>/dev/null || echo "Unknown")
  if [[ "$STATE" == "Succeeded" ]]; then
    echo ">>> Provisioning complete"
    break
  fi
  echo ">>> Provisioning state: ${STATE} — waiting 10s ($i/30)..."
  sleep 10
done

# Get endpoint
DOC_INTEL_ENDPOINT=$(az cognitiveservices account show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DOC_INTEL_NAME" \
  --query properties.endpoint --output tsv)

# Store endpoint in Key Vault for app configuration
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "doc-intel-endpoint" \
  --value "$DOC_INTEL_ENDPOINT" \
  --output none 2>/dev/null || true

echo ">>> Document Intelligence (cloud) ready: ${DOC_INTEL_ENDPOINT}"
echo ">>> Auth: use managed identity with 'Cognitive Services User' RBAC role"
