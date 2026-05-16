#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/params/${ENV_NAME:-dev}.env"

echo ">>> Creating Qdrant VM: ${VM_NAME} (${VM_SIZE})"

# Cloud-init script to install Docker and Qdrant
CLOUD_INIT=$(cat <<'CLOUD_INIT_EOF'
#!/bin/bash
set -euo pipefail

# Install Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker azureuser

# Create Qdrant data directory
mkdir -p /data/qdrant
chown azureuser:azureuser /data/qdrant

# Run Qdrant (API key set via env var at runtime)
docker run -d \
  --name qdrant \
  -p 6333:6333 \
  -p 6334:6334 \
  -v /data/qdrant:/qdrant/storage:z \
  --restart unless-stopped \
  qdrant/qdrant

# Install Python 3.11 for embedding pipeline
apt-get update
apt-get install -y python3.11 python3.11-venv
python3.11 -m venv /opt/ingestion/venv
/opt/ingestion/venv/bin/pip install \
  qdrant-client openai azure-identity \
  azure-ai-documentintelligence sentence-transformers

# Download re-ranking model
/opt/ingestion/venv/bin/python -c "
from sentence_transformers import CrossEncoder
CrossEncoder('cross-encoder/ms-marco-MiniLM-L-12-v2')
"
CLOUD_INIT_EOF
)

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --location "$LOCATION" \
  --image "$VM_IMAGE" \
  --size "$VM_SIZE" \
  --admin-username "$VM_ADMIN" \
  --generate-ssh-keys \
  --assign-identity \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_VM" \
  --nsg "$VM_NSG" \
  --os-disk-size-gb 256 \
  --storage-sku Premium_LRS \
  --custom-data <(echo "$CLOUD_INIT") \
  --output json

echo ">>> VM ${VM_NAME} created with Qdrant + embedding pipeline"
