#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-RAG-AI-Infra}.env"

echo ">>> Deleting Key Vault: ${KV_NAME}"

az keyvault delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$KV_NAME" \
  --output none 2>/dev/null || true

# Purge to free the name
az keyvault purge \
  --name "$KV_NAME" \
  --output none 2>/dev/null || true

echo ">>> Key Vault ${KV_NAME} deleted and purged"
