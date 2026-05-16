#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Deleting Container Apps Environment: ${CAE_NAME}"

az containerapp env delete \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CAE_NAME" \
  --yes \
  --output none 2>/dev/null || true

echo ">>> Container Apps Environment ${CAE_NAME} deleted"
