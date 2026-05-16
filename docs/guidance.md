---
layout: default
title: "Quick Reference"
nav_order: 12
---

# Workshop Quick Reference

## Overview

This workshop walks through building a RAG chatbot on Azure infrastructure provisioned with Azure CLI scripts.

## Prerequisites

1. **Azure subscription** with GPU quota for `Standard_NV36ads_A10_v5` in `indonesiacentral`
2. **Azure CLI** v2.60+ installed and logged in
3. **Bash shell** (WSL2 on Windows, native on Linux/macOS)
4. **Python 3.11+**
5. **Docker** (for local development)
6. **SSH key pair** at `~/.ssh/id_rsa`

## Workshop Flow

### Step 1: Deploy Infrastructure

```bash
cd infra
ENV_NAME=dev bash deploy.sh
```

This provisions (in order):
1. Resource group (`project-lab-dev`)
2. VNet with 3 subnets + NSGs
3. Container Registry
4. Key Vault
5. AI Foundry with `text-embedding-3-small` deployment
6. Qdrant VM with Docker + embedding pipeline
7. Document Intelligence (commitment resource + disconnected container on VM)
8. GPU VM with NVIDIA driver extension + vLLM + Qwen3.5-9B
9. Container Apps environment + backend + frontend
10. RBAC role assignments

### Step 2: Ingest Documents

```bash
cd ingestion
pip install -r requirements.txt
python ingest.py --source ./sample-docs/
```

Documents flow through:
- **Document Intelligence** (disconnected container on VM) — extract text from PDFs/images
- **Azure AI Foundry** — generate embeddings (`text-embedding-3-small`, 1536 dims)
- **Qdrant** — store vectors with metadata

### Step 3: Build & Push Application Images

```bash
# Login to ACR
az acr login --name chatbotdevacr

# Build and push backend
cd backend
docker build -t chatbotdevacr.azurecr.io/chatbot-backend:latest .
docker push chatbotdevacr.azurecr.io/chatbot-backend:latest

# Build and push frontend
cd ../frontend
docker build -t chatbotdevacr.azurecr.io/chatbot-frontend:latest .
docker push chatbotdevacr.azurecr.io/chatbot-frontend:latest
```

### Step 4: Update Container Apps

Re-run the container app modules to pick up new images:

```bash
cd infra
bash modules/container-app-backend.sh
bash modules/container-app-frontend.sh
```

### Step 5: Test the Chatbot

Open the frontend URL printed by the deployment and start chatting.

## Networking

| Subnet | CIDR | Resources |
|---|---|---|
| `vm-subnet` | `10.0.1.0/24` | Qdrant VM |
| `gpu-subnet` | `10.0.2.0/24` | GPU VM (vLLM) |
| `apps-subnet` | `10.0.3.0/27` | Container Apps |

NSG rules ensure Qdrant (6333/6334) and vLLM (8000) are only accessible from within the VNet.

## Troubleshooting

### GPU VM not responding

```bash
# Check NVIDIA driver extension status
az vm extension list --resource-group project-lab-dev --vm-name chatbot-dev-gpu -o table

# SSH in and verify
ssh azureuser@<GPU_VM_IP>
nvidia-smi
systemctl status vllm.service
docker logs vllm-qwen
```

### Qdrant not reachable

```bash
ssh azureuser@<VM_IP>
docker ps
docker logs qdrant
curl http://localhost:6333/healthz
```

### Container App not starting

```bash
az containerapp logs show \
  --resource-group project-lab-dev \
  --name chatbot-dev-backend \
  --type console
```

## Cleanup

```bash
cd infra
ENV_NAME=dev bash destroy.sh         # clean individual deletion
ENV_NAME=dev bash destroy.sh --fast  # fast: delete resource group
```
