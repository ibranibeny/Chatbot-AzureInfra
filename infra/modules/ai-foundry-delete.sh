#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Deleting AI Foundry account: ${AI_ACCOUNT_NAME}"

# Delete deployment first
az cognitiveservices account deployment delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AI_ACCOUNT_NAME" \
  --deployment-name "$EMBEDDING_DEPLOYMENT" \
  --output none 2>/dev/null || true

az cognitiveservices account delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AI_ACCOUNT_NAME" \
  --output none 2>/dev/null || true

# Purge soft-deleted account
az cognitiveservices account purge \
  --location "$LOCATION" \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AI_ACCOUNT_NAME" \
  --output none 2>/dev/null || true

echo ">>> AI Foundry ${AI_ACCOUNT_NAME} deleted"
