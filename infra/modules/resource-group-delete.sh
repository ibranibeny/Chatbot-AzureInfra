#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Deleting resource group: ${RESOURCE_GROUP}"
echo ">>> WARNING: This deletes ALL resources in the group!"

az group delete \
  --name "$RESOURCE_GROUP" \
  --yes \
  --no-wait \
  --output none 2>/dev/null || true

echo ">>> Resource group ${RESOURCE_GROUP} deletion initiated"
