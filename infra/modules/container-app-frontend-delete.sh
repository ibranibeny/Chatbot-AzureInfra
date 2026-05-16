#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Deleting frontend Container App: ${CA_FRONTEND_NAME}"

az containerapp delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_FRONTEND_NAME" \
  --yes \
  --output none 2>/dev/null || true

echo ">>> Frontend Container App ${CA_FRONTEND_NAME} deleted"
