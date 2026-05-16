#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-RAG-AI-Infra}.env"

echo ">>> Creating Key Vault: ${KV_NAME}"

az keyvault create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$KV_NAME" \
  --location "$LOCATION" \
  --enable-rbac-authorization true \
  --output none 2>/dev/null || true

echo ">>> Key Vault ${KV_NAME} ready"
