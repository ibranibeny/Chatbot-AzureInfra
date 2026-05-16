#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# doc-intelligence.sh — Provision Document Intelligence commitment resource
#                       and deploy disconnected container on the Qdrant VM
#
# Creates:
#   1. Azure Cognitive Services (FormRecognizer) with commitment tier pricing
#   2. Pulls Doc Intel container image on the VM
#   3. Downloads license via one-time connected run
#   4. Starts disconnected container on port 5050
#
# Idempotent: safe to re-run
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Creating Document Intelligence commitment resource: ${DOC_INTEL_NAME}"

# 1. Create the Cognitive Services resource for disconnected container license
# NOTE: FormRecognizer is not available in indonesiacentral; use southeastasia
# The resource is only needed for license download — the container runs locally on the VM
DOC_INTEL_LOCATION="southeastasia"
echo ">>> Using ${DOC_INTEL_LOCATION} for FormRecognizer resource (not available in ${LOCATION})"

az cognitiveservices account create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DOC_INTEL_NAME" \
  --location "$DOC_INTEL_LOCATION" \
  --kind FormRecognizer \
  --sku S0 \
  --custom-domain "$DOC_INTEL_NAME" \
  --output none 2>/dev/null || true

# Ensure local auth is enabled (needed for license key download)
az rest --method patch \
  --url "https://management.azure.com$(az cognitiveservices account show \
    --resource-group "$RESOURCE_GROUP" --name "$DOC_INTEL_NAME" \
    --query id --output tsv)?api-version=2023-05-01" \
  --body '{"properties":{"disableLocalAuth":false}}' \
  --output none 2>/dev/null || true

# 2. Get endpoint and key for license download
DOC_INTEL_ENDPOINT=$(az cognitiveservices account show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DOC_INTEL_NAME" \
  --query properties.endpoint --output tsv)

DOC_INTEL_KEY=$(az cognitiveservices account keys list \
  --resource-group "$RESOURCE_GROUP" \
  --name "$DOC_INTEL_NAME" \
  --query key1 --output tsv)

# Store key in Key Vault for reference (used only for license download)
az keyvault secret set \
  --vault-name "$KV_NAME" \
  --name "doc-intel-key" \
  --value "$DOC_INTEL_KEY" \
  --output none 2>/dev/null || true

echo ">>> Setting up Document Intelligence disconnected container on VM: ${VM_NAME}"

# 3. SSH into the VM and configure the disconnected container
VM_IP=$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --show-details \
  --query publicIps --output tsv)

ssh -o StrictHostKeyChecking=no azureuser@"$VM_IP" << REMOTE_SCRIPT
set -euo pipefail

# Create directories
sudo mkdir -p ${DOC_INTEL_LICENSE_DIR} ${DOC_INTEL_OUTPUT_DIR}
sudo chown -R azureuser:azureuser /data/doc-intel

# Pull container image
docker pull ${DOC_INTEL_IMAGE}

# Check if license already exists (skip download if so)
if [ ! -f "${DOC_INTEL_LICENSE_DIR}/license.lic" ]; then
  echo ">>> Downloading license (one-time connected operation)..."
  docker run --rm \
    -v ${DOC_INTEL_LICENSE_DIR}:/license \
    ${DOC_INTEL_IMAGE} \
    eula=accept \
    billing="${DOC_INTEL_ENDPOINT}" \
    apikey="${DOC_INTEL_KEY}" \
    DownloadLicense=True \
    Mounts:License=/license
  echo ">>> License downloaded successfully"
else
  echo ">>> License already exists, skipping download"
fi

# Stop existing container if running
docker rm -f doc-intel 2>/dev/null || true

# Run disconnected container
docker run -d \
  --name doc-intel \
  -p ${DOC_INTEL_PORT}:5050 \
  -v ${DOC_INTEL_LICENSE_DIR}:/license \
  -v ${DOC_INTEL_OUTPUT_DIR}:/output \
  --restart unless-stopped \
  ${DOC_INTEL_IMAGE} \
  eula=accept \
  Mounts:License=/license \
  Mounts:Output=/output

echo ">>> Document Intelligence container running on port ${DOC_INTEL_PORT}"
REMOTE_SCRIPT

echo ">>> Document Intelligence disconnected container deployed on ${VM_NAME}"
