#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-RAG-AI-Infra}.env"

echo ">>> Removing RBAC role assignments"

RG_ID=$(az group show --name "$RESOURCE_GROUP" --query id --output tsv 2>/dev/null || echo "")

if [[ -z "$RG_ID" ]]; then
  echo ">>> Resource group not found — nothing to clean up"
  exit 0
fi

# Remove all role assignments scoped to this resource group
ASSIGNMENTS=$(az role assignment list \
  --scope "$RG_ID" \
  --query "[].id" --output tsv 2>/dev/null || echo "")

for ASSIGNMENT_ID in $ASSIGNMENTS; do
  echo ">>> Removing role assignment: ${ASSIGNMENT_ID}"
  az role assignment delete --ids "$ASSIGNMENT_ID" --output none 2>/dev/null || true
done

echo ">>> RBAC role assignments cleaned up"
