#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Deploying backend Container App: ${CA_BACKEND_NAME}"

# Get VM public IPs (Container Apps in LOCATION_APPS can't reach private IPs in LOCATION)
VM_PUBLIC_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --show-details \
  --query publicIps --output tsv 2>/dev/null || echo "")

GPU_PUBLIC_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_GPU_NAME" \
  --show-details \
  --query publicIps --output tsv 2>/dev/null || echo "")

AI_ENDPOINT=$(az cognitiveservices account show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AI_ACCOUNT_NAME" \
  --query "properties.endpoint" --output tsv 2>/dev/null || echo "")

# ACR admin credentials (workaround: --registry-identity system requires pre-existing identity)
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query "passwords[0].value" --output tsv)

az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_BACKEND_NAME" \
  --environment "$CAE_NAME" \
  --image "${ACR_NAME}.azurecr.io/${PROJECT}-backend:latest" \
  --target-port 8000 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 3 \
  --cpu 1 --memory 2Gi \
  --registry-server "${ACR_NAME}.azurecr.io" \
  --registry-username "$ACR_NAME" \
  --registry-password "$ACR_PASSWORD" \
  --env-vars \
    "QDRANT_URL=http://${VM_PUBLIC_IP}:${QDRANT_PORT}" \
    "QDRANT_COLLECTION=${QDRANT_COLLECTION:-documents}" \
    "VLLM_BASE_URL=http://${GPU_PUBLIC_IP}:${VLLM_PORT}/v1" \
    "VLLM_MODEL=${VLLM_MODEL}" \
    "AZURE_AI_ENDPOINT=${AI_ENDPOINT}" \
    "EMBEDDING_DEPLOYMENT=${EMBEDDING_DEPLOYMENT}" \
  --output none 2>/dev/null || \
az containerapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_BACKEND_NAME" \
  --image "${ACR_NAME}.azurecr.io/${PROJECT}-backend:latest" \
  --set-env-vars \
    "QDRANT_URL=http://${VM_PUBLIC_IP}:${QDRANT_PORT}" \
    "QDRANT_COLLECTION=${QDRANT_COLLECTION:-documents}" \
    "VLLM_BASE_URL=http://${GPU_PUBLIC_IP}:${VLLM_PORT}/v1" \
    "VLLM_MODEL=${VLLM_MODEL}" \
    "AZURE_AI_ENDPOINT=${AI_ENDPOINT}" \
    "EMBEDDING_DEPLOYMENT=${EMBEDDING_DEPLOYMENT}" \
  --output none

# Enable system-assigned identity after creation
az containerapp identity assign \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_BACKEND_NAME" \
  --system-assigned \
  --output none 2>/dev/null || true

BACKEND_URL=$(az containerapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_BACKEND_NAME" \
  --query "properties.configuration.ingress.fqdn" --output tsv)

echo ">>> Backend deployed: https://${BACKEND_URL}"
