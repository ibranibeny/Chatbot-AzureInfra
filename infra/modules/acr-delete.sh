#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Deleting Container Registry: ${ACR_NAME}"

az acr delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$ACR_NAME" \
  --yes \
  --output none 2>/dev/null || true

echo ">>> Container Registry ${ACR_NAME} deleted"
