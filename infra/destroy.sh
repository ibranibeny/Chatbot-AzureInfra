#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# destroy.sh — Tear down all Chatbot-AzureInfra resources
#
# Usage:
#   ENV_NAME=dev bash destroy.sh          # destroy dev environment
#   ENV_NAME=dev bash destroy.sh --fast   # delete resource group directly
#   bash destroy.sh                       # defaults to dev
#
# Without --fast: deletes resources individually in reverse order (clean)
# With --fast:    deletes the entire resource group at once (faster)
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
export ENV_NAME="${ENV_NAME:-RAG-AI-Infra}"

source "${SCRIPT_DIR}/params/${ENV_NAME}.env"

FAST_MODE="${1:-}"

echo "============================================================"
echo "  DESTROYING Chatbot-AzureInfra — env: ${ENV_NAME}"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "============================================================"
echo ""

# Confirm
read -r -p "Are you sure you want to destroy ALL resources in ${RESOURCE_GROUP}? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

START_TIME=$(date +%s)

if [[ "$FAST_MODE" == "--fast" ]]; then
  echo ">>> Fast mode: deleting entire resource group"
  bash "${MODULES_DIR}/resource-group-delete.sh"
else
  # Reverse order: RBAC → Apps → VMs → Services → Network → RG

  echo "=== [1/10] Removing RBAC ==="
  bash "${MODULES_DIR}/identity-roles-delete.sh"
  echo ""

  echo "=== [2/10] Deleting Frontend Container App ==="
  bash "${MODULES_DIR}/container-app-frontend-delete.sh"
  echo ""

  echo "=== [3/10] Deleting Backend Container App ==="
  bash "${MODULES_DIR}/container-app-backend-delete.sh"
  echo ""

  echo "=== [4/10] Deleting Container Apps Environment ==="
  bash "${MODULES_DIR}/container-app-env-delete.sh"
  echo ""

  echo "=== [5/10] Deleting GPU VM ==="
  bash "${MODULES_DIR}/vm-gpu-delete.sh"
  echo ""

  echo "=== [6/10] Stopping Doc Intelligence container + deleting commitment resource ==="
  bash "${MODULES_DIR}/doc-intelligence-delete.sh"
  echo ""

  echo "=== [7/10] Deleting Qdrant VM ==="
  bash "${MODULES_DIR}/vm-delete.sh"
  echo ""

  echo "=== [8/10] Deleting AI Foundry ==="
  bash "${MODULES_DIR}/ai-foundry-delete.sh"
  echo ""

  echo "=== [9/10] Deleting Key Vault ==="
  bash "${MODULES_DIR}/keyvault-delete.sh"
  echo ""

  echo "=== [10/10] Deleting ACR + Networking ==="
  bash "${MODULES_DIR}/acr-delete.sh"
  bash "${MODULES_DIR}/vnet-delete.sh"
  echo ""

  echo ">>> Deleting resource group shell"
  bash "${MODULES_DIR}/resource-group-delete.sh"
fi

END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))

echo ""
echo "============================================================"
echo "  Destroy complete! (${ELAPSED}s)"
echo "============================================================"
