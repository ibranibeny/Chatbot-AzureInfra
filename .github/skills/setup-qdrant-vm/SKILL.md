---
name: setup-qdrant-vm
description: "Set up the multi-purpose VM with Qdrant vector database, embedding processing, and re-ranking. Use when: provisioning Qdrant, configuring vector DB, setting up document ingestion VM, embedding pipeline."
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

### 5. Configure Document Intelligence Access
Document Intelligence runs as a **cloud service** in `southeastasia` — NOT as a container on this VM.

**Prerequisites**: An Azure `FormRecognizer` resource (S0) must exist (provisioned by `infra/modules/doc-intelligence.sh`).

The VM’s managed identity needs the `Cognitive Services User` RBAC role to call the cloud API.
The endpoint is stored in Key Vault as `doc-intel-endpoint`.

```bash
# Get endpoint from Key Vault
DOC_INTEL_ENDPOINT=$(az keyvault secret show \
  --vault-name "$KV_NAME" --name doc-intel-endpoint \
  --query value --output tsv)
```

The embedding pipeline on this VM calls the cloud endpoint for document parsing via HTTPS.

### 6. Configure Cloud Doc Intelligence Access
- **Auth**: Managed identity with `Cognitive Services User` RBAC role
- **Endpoint**: Stored in Key Vault as `doc-intel-endpoint`
- **No container or license needed** — fully managed cloud service
- The ingestion pipeline calls the cloud API via HTTPS

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
