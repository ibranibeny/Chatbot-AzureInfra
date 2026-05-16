#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Assigning RBAC roles (managed identity)"

# Get identities
VM_IDENTITY=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --query identity.principalId --output tsv 2>/dev/null || echo "")

GPU_IDENTITY=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_GPU_NAME" \
  --query identity.principalId --output tsv 2>/dev/null || echo "")

BACKEND_IDENTITY=$(az containerapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_BACKEND_NAME" \
  --query identity.principalId --output tsv 2>/dev/null || echo "")

# Scope
RG_ID=$(az group show --name "$RESOURCE_GROUP" --query id --output tsv)

# --- Qdrant VM roles ---
if [[ -n "$VM_IDENTITY" ]]; then
  echo ">>> Granting Qdrant VM: Cognitive Services User (AI Foundry)"
  az role assignment create \
    --assignee-object-id "$VM_IDENTITY" \
    --assignee-principal-type ServicePrincipal \
    --role "Cognitive Services User" \
    --scope "$RG_ID" \
    --output none 2>/dev/null || true

  echo ">>> Granting Qdrant VM: Cognitive Services OpenAI User"
  az role assignment create \
    --assignee-object-id "$VM_IDENTITY" \
    --assignee-principal-type ServicePrincipal \
    --role "Cognitive Services OpenAI User" \
    --scope "$RG_ID" \
    --output none 2>/dev/null || true
fi

# --- Backend Container App roles ---
if [[ -n "$BACKEND_IDENTITY" ]]; then
  echo ">>> Granting Backend: Cognitive Services OpenAI User"
  az role assignment create \
    --assignee-object-id "$BACKEND_IDENTITY" \
    --assignee-principal-type ServicePrincipal \
    --role "Cognitive Services OpenAI User" \
    --scope "$RG_ID" \
    --output none 2>/dev/null || true

  echo ">>> Granting Backend: AcrPull"
  ACR_ID=$(az acr show --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --query id --output tsv)
  az role assignment create \
    --assignee-object-id "$BACKEND_IDENTITY" \
    --assignee-principal-type ServicePrincipal \
    --role AcrPull \
    --scope "$ACR_ID" \
    --output none 2>/dev/null || true
fi

# --- Frontend Container App AcrPull ---
FRONTEND_IDENTITY=$(az containerapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_FRONTEND_NAME" \
  --query identity.principalId --output tsv 2>/dev/null || echo "")

if [[ -n "$FRONTEND_IDENTITY" ]]; then
  echo ">>> Granting Frontend: AcrPull"
  ACR_ID=$(az acr show --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" --query id --output tsv)
  az role assignment create \
    --assignee-object-id "$FRONTEND_IDENTITY" \
    --assignee-principal-type ServicePrincipal \
    --role AcrPull \
    --scope "$ACR_ID" \
    --output none 2>/dev/null || true
fi

echo ">>> RBAC role assignments complete"
