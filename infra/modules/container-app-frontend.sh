#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Deploying frontend Container App: ${CA_FRONTEND_NAME}"

# Get backend URL
BACKEND_URL=$(az containerapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_BACKEND_NAME" \
  --query "properties.configuration.ingress.fqdn" --output tsv 2>/dev/null || echo "")

az containerapp create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_FRONTEND_NAME" \
  --environment "$CAE_NAME" \
  --image "${ACR_NAME}.azurecr.io/${PROJECT}-frontend:latest" \
  --target-port 8501 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 3 \
  --cpu 0.5 --memory 1Gi \
  --registry-server "${ACR_NAME}.azurecr.io" \
  --registry-identity system \
  --system-assigned \
  --env-vars \
    "BACKEND_URL=https://${BACKEND_URL}" \
  --output none 2>/dev/null || \
az containerapp update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_FRONTEND_NAME" \
  --image "${ACR_NAME}.azurecr.io/${PROJECT}-frontend:latest" \
  --set-env-vars \
    "BACKEND_URL=https://${BACKEND_URL}" \
  --output none

FRONTEND_URL=$(az containerapp show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$CA_FRONTEND_NAME" \
  --query "properties.configuration.ingress.fqdn" --output tsv)

echo ">>> Frontend deployed: https://${FRONTEND_URL}"
