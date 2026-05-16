---
name: setup-qdrant-vm
description: "Set up the multi-purpose VM with Qdrant vector database, Document Intelligence, embedding processing, and re-ranking. Use when: provisioning Qdrant, configuring vector DB, setting up document ingestion VM, embedding pipeline."
---

# Set Up Multi-Purpose VM

Provisions and configures the workshop VM running Qdrant, embedding processing, and re-ranking services.

## VM Specification
- **SKU**: `Standard_D8s_v5` (8 vCPU, 32 GB RAM) — workshop default
- **OS**: Ubuntu 22.04 LTS
- **Managed disk**: 256 GB Premium SSD for Qdrant data persistence
- **Region**: `indonesiacentral`
- **Identity**: System-assigned managed identity

## Services on the VM

| Service | How | Port | Data Dir |
|---|---|---|---|
| Qdrant | Docker container | 6333 (REST), 6334 (gRPC) | `/data/qdrant` |
| Document Intelligence | Docker container (disconnected) | 5050 | `/data/doc-intel` |
| Embedding pipeline | Python scripts | N/A (batch job) | `/opt/ingestion` |
| Re-ranking | Python service (cross-encoder) | 8001 (optional) | N/A |

## Steps

### 1. Provision the VM
```bash
source ./params/${ENV_NAME}.env

az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "${PROJECT}-${ENV_NAME}-vm" \
  --location "$LOCATION" \
  --image Ubuntu2204 \
  --size Standard_D8s_v5 \
  --admin-username azureuser \
  --generate-ssh-keys \
  --assign-identity \
  --vnet-name "${PROJECT}-${ENV_NAME}-vnet" \
  --subnet "vm-subnet" \
  --nsg "${PROJECT}-${ENV_NAME}-vm-nsg" \
  --output json
```

### 2. Install Docker + deploy Qdrant
Reference: https://qdrant.tech/documentation/quickstart/
```bash
ssh azureuser@<VM_IP>

# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker azureuser

# Create data directory
sudo mkdir -p /data/qdrant
sudo chown azureuser:azureuser /data/qdrant

# Run Qdrant with API key security
docker run -d \
  --name qdrant \
  -p 6333:6333 \
  -p 6334:6334 \
  -v /data/qdrant:/qdrant/storage:z \
  -e QDRANT__SERVICE__API_KEY="${QDRANT_API_KEY}" \
  --restart unless-stopped \
  qdrant/qdrant
```

### 3. Configure NSG rules
```bash
# Allow Qdrant only from VNet
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "${PROJECT}-${ENV_NAME}-vm-nsg" \
  --name AllowQdrantFromVNet \
  --priority 100 \
  --source-address-prefixes VirtualNetwork \
  --destination-port-ranges 6333 6334 \
  --access Allow --protocol Tcp --output none

# Deny Qdrant from internet
az network nsg rule create \
  --resource-group "$RESOURCE_GROUP" \
  --nsg-name "${PROJECT}-${ENV_NAME}-vm-nsg" \
  --name DenyQdrantFromInternet \
  --priority 200 \
  --source-address-prefixes Internet \
  --destination-port-ranges 6333 6334 \
  --access Deny --protocol Tcp --output none
```

### 4. Set up embedding pipeline
```bash
# Install Python environment
sudo apt-get install -y python3.11 python3.11-venv
python3.11 -m venv /opt/ingestion/venv
source /opt/ingestion/venv/bin/activate
pip install qdrant-client openai azure-identity requests sentence-transformers
```

### 5. Deploy Document Intelligence Disconnected Container
Reference: https://learn.microsoft.com/azure/ai-services/document-intelligence/containers/disconnected
Document Intelligence runs as a **disconnected Docker container** on this VM — NOT as an Azure managed service.

**Prerequisites**: An Azure `FormRecognizer` resource with commitment tier pricing must exist (provisioned by `infra/modules/doc-intelligence.sh`).

```bash
# Create directories
sudo mkdir -p /data/doc-intel/license /data/doc-intel/output
sudo chown -R azureuser:azureuser /data/doc-intel

# Pull the container image
docker pull mcr.microsoft.com/azure-cognitive-services/form-recognizer/layout-3.0:latest

# Step 1: Download license (requires one-time internet connectivity)
# Get endpoint and key from the Azure FormRecognizer resource
DOC_INTEL_ENDPOINT=$(az cognitiveservices account show \
  --resource-group "$RESOURCE_GROUP" --name "$DOC_INTEL_NAME" \
  --query properties.endpoint --output tsv)
DOC_INTEL_KEY=$(az cognitiveservices account keys list \
  --resource-group "$RESOURCE_GROUP" --name "$DOC_INTEL_NAME" \
  --query key1 --output tsv)

docker run --rm -it \
  -v /data/doc-intel/license:/license \
  mcr.microsoft.com/azure-cognitive-services/form-recognizer/layout-3.0:latest \
  eula=accept \
  billing="$DOC_INTEL_ENDPOINT" \
  apikey="$DOC_INTEL_KEY" \
  DownloadLicense=True \
  Mounts:License=/license

# Step 2: Run disconnected (no internet needed after this point)
docker run -d \
  --name doc-intel \
  -p 5050:5050 \
  -v /data/doc-intel/license:/license \
  -v /data/doc-intel/output:/output \
  --restart unless-stopped \
  mcr.microsoft.com/azure-cognitive-services/form-recognizer/layout-3.0:latest \
  eula=accept \
  Mounts:License=/license \
  Mounts:Output=/output
```

The embedding pipeline on this VM calls `http://localhost:5050` for document parsing — no network egress required.

### 6. Configure Document Intelligence Access
- **No NSG rule needed** — the container is accessed via localhost only
- The Azure `FormRecognizer` commitment resource is only needed for license download
- After license download, the container runs fully offline
- Store the API key in Key Vault (used only during initial license download)

### 7. Embedding models

| Content Type | Model | Source | Dimensions |
|---|---|---|---|
| Text | `text-embedding-3-small` | Azure AI Foundry (API) | 1536 |
| Images | Azure AI Vision embeddings OR `text-embedding-3-large` | Azure AI Foundry (API) | 3072 |
| Re-ranking | `cross-encoder/ms-marco-MiniLM-L-12-v2` | Local on VM (sentence-transformers) | N/A |

**Image embedding decision**:
- High volume of images → Azure AI Vision embeddings (optimized for visual content)
- Mixed text+image documents → `text-embedding-3-large` (unified vector space)

### 8. Create Qdrant collection
```python
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams

client = QdrantClient(url="http://localhost:6333", api_key=QDRANT_API_KEY)

client.create_collection(
    collection_name="documents",
    vectors_config=VectorParams(size=1536, distance=Distance.COSINE),
)
```

## Qdrant Documentation
- Docs: https://qdrant.tech/documentation/
- Security: https://qdrant.tech/documentation/security/
- Collections & indexing: https://qdrant.tech/documentation/manage-data/
- Search & filtering: https://qdrant.tech/documentation/search/
