#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Creating Container Apps Environment: ${CAE_NAME}"

az containerapp env create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CAE_NAME" \
  --location "${LOCATION_APPS:-$LOCATION}" \
  --output none 2>/dev/null || true

echo ">>> Container Apps Environment ${CAE_NAME} ready"
