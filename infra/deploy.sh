#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# deploy.sh — Main deployment orchestrator for Chatbot-AzureInfra
#
# Usage:
#   ENV_NAME=dev bash deploy.sh          # deploy dev environment
#   ENV_NAME=prod bash deploy.sh         # deploy prod environment
#   bash deploy.sh                       # defaults to dev
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"
export ENV_NAME="${ENV_NAME:-RAG-AI-Infra}"

source "${SCRIPT_DIR}/params/${ENV_NAME}.env"

echo "============================================================"
echo "  Deploying Chatbot-AzureInfra — env: ${ENV_NAME}"
echo "  Resource Group: ${RESOURCE_GROUP}"
echo "  Location:       ${LOCATION}"
echo "============================================================"
echo ""

START_TIME=$(date +%s)

# 1. Resource Group
echo "=== [1/10] Resource Group ==="
bash "${MODULES_DIR}/resource-group.sh"
echo ""

# 2. Networking (VNet, Subnets, NSGs)
echo "=== [2/10] Networking ==="
bash "${MODULES_DIR}/vnet.sh"
echo ""

# 3. Container Registry
echo "=== [3/10] Container Registry ==="
bash "${MODULES_DIR}/acr.sh"
echo ""

# 4. Key Vault
echo "=== [4/10] Key Vault ==="
bash "${MODULES_DIR}/keyvault.sh"
echo ""

# 5. AI Foundry (OpenAI + Embeddings)
echo "=== [5/10] AI Foundry ==="
bash "${MODULES_DIR}/ai-foundry.sh"
echo ""

# 6. Qdrant VM (must be up before Doc Intelligence container)
echo "=== [6/10] Qdrant VM ==="
bash "${MODULES_DIR}/vm.sh"
echo ""

# 7. Document Intelligence (commitment resource + disconnected container on VM)
echo "=== [7/10] Document Intelligence (disconnected container) ==="
bash "${MODULES_DIR}/doc-intelligence.sh"
echo ""

# 8. GPU VM (vLLM + Qwen3.5-9B)
echo "=== [8/10] GPU VM (vLLM) ==="
bash "${MODULES_DIR}/vm-gpu.sh"
echo ""

# 9. Container Apps (Environment + Backend + Frontend)
echo "=== [9/10] Container Apps ==="
bash "${MODULES_DIR}/container-app-env.sh"
bash "${MODULES_DIR}/container-app-backend.sh"
bash "${MODULES_DIR}/container-app-frontend.sh"
echo ""

# 10. RBAC Role Assignments
echo "=== [10/10] Identity & RBAC ==="
bash "${MODULES_DIR}/identity-roles.sh"
echo ""

END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))

echo "============================================================"
echo "  Deployment complete! (${ELAPSED}s)"
echo "============================================================"
echo ""
echo "Resources deployed in ${RESOURCE_GROUP}:"
az resource list --resource-group "$RESOURCE_GROUP" --query "[].{Name:name, Type:type}" --output table
