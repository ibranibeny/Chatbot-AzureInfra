#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Creating Azure AI Services account: ${AI_ACCOUNT_NAME}"

az cognitiveservices account create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AI_ACCOUNT_NAME" \
  --location "$LOCATION" \
  --kind OpenAI \
  --sku S0 \
  --assign-identity \
  --output none 2>/dev/null || true

echo ">>> Deploying embedding model: ${EMBEDDING_DEPLOYMENT}"

az cognitiveservices account deployment create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AI_ACCOUNT_NAME" \
  --deployment-name "$EMBEDDING_DEPLOYMENT" \
  --model-name "$EMBEDDING_MODEL" \
  --model-version "1" \
  --model-format OpenAI \
  --sku-name Standard \
  --sku-capacity 120 \
  --output none 2>/dev/null || true

echo ">>> AI Foundry ${AI_ACCOUNT_NAME} with ${EMBEDDING_DEPLOYMENT} ready"
