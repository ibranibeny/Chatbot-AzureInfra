#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-RAG-AI-Infra}.env"

echo ">>> Deleting backend Container App: ${CA_BACKEND_NAME}"

az containerapp delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_BACKEND_NAME" \
  --yes \
  --output none 2>/dev/null || true

echo ">>> Backend Container App ${CA_BACKEND_NAME} deleted"
