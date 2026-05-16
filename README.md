# Chatbot-AzureInfra

A **RAG (Retrieval-Augmented Generation) chatbot** workshop that provisions Azure infrastructure using Azure CLI scripts.

## Architecture

| Component | Technology | Azure Service / SKU |
|---|---|---|
| Frontend | Streamlit (Python) | Azure Container Apps |
| Backend (RAG API) | Python (FastAPI) | Azure Container Apps |
| LLM Serving | vLLM + Qwen3.5-9B | GPU VM — `Standard_NV36ads_A10_v5` |
| Vector Database | Qdrant (Docker) | VM — `Standard_D8s_v5` |
| Embeddings (text) | `text-embedding-3-small` | Azure AI Foundry |
| Re-ranking | `cross-encoder/ms-marco-MiniLM-L-12-v2` | Local on VM |
| Document Processing | Document Intelligence (cloud) | Azure Cognitive Services S0 (`southeastasia`) |
| Region | — | `indonesiacentral` |

## Data Flow

1. Documents → **Document Intelligence** (cloud API in `southeastasia`) → chunked → embedded via **Azure AI Foundry** → stored in **Qdrant**
2. User query → **Streamlit** → **FastAPI** → embed query → Qdrant search → re-rank → context + prompt → **vLLM (Qwen3.5-9B)** → response

## Quick Start

### Prerequisites

- Azure CLI (`az`) logged in with appropriate subscription
- Bash shell (WSL, Linux, macOS)
- SSH key pair (`~/.ssh/id_rsa`)

### Deploy

```bash
cd infra
ENV_NAME=dev bash deploy.sh
```

### Destroy

```bash
cd infra
ENV_NAME=dev bash destroy.sh          # individual resource deletion
ENV_NAME=dev bash destroy.sh --fast   # delete entire resource group
```

### Run Locally

```bash
# Backend
cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload

# Frontend
cd frontend && pip install -r requirements.txt && streamlit run app.py

# Ingestion
cd ingestion && pip install -r requirements.txt && python ingest.py
```

## Project Structure

```
├── AGENTS.md                 # AI agent instructions
├── README.md                 # This file
├── infra/                    # Azure CLI provisioning scripts
│   ├── deploy.sh             # Main deployment orchestrator
│   ├── destroy.sh            # Teardown orchestrator
│   ├── params/               # Environment parameter files
│   │   └── dev.env
│   └── modules/              # Per-resource scripts
│       ├── resource-group.sh / resource-group-delete.sh
│       ├── vnet.sh           / vnet-delete.sh
│       ├── acr.sh            / acr-delete.sh
│       ├── keyvault.sh       / keyvault-delete.sh
│       ├── vm.sh             / vm-delete.sh
│       ├── vm-gpu.sh         / vm-gpu-delete.sh
│       ├── ai-foundry.sh     / ai-foundry-delete.sh
│       ├── doc-intelligence.sh / doc-intelligence-delete.sh
│       ├── container-app-env.sh / container-app-env-delete.sh
│       ├── container-app-backend.sh / container-app-backend-delete.sh
│       ├── container-app-frontend.sh / container-app-frontend-delete.sh
│       └── identity-roles.sh / identity-roles-delete.sh
├── backend/                  # FastAPI RAG service
├── frontend/                 # Streamlit chat UI
├── ingestion/                # Document ingestion pipeline
└── docs/                     # Workshop docs & architecture diagram
```

## Infrastructure Modules

| # | Module | Deploy | Delete |
|---|---|---|---|
| 1 | Resource Group | `resource-group.sh` | `resource-group-delete.sh` |
| 2 | VNet + Subnets + NSGs | `vnet.sh` | `vnet-delete.sh` |
| 3 | Container Registry | `acr.sh` | `acr-delete.sh` |
| 4 | Key Vault | `keyvault.sh` | `keyvault-delete.sh` |
| 5 | AI Foundry (Embeddings) | `ai-foundry.sh` | `ai-foundry-delete.sh` |
| 6 | Document Intelligence (cloud) | `doc-intelligence.sh` | `doc-intelligence-delete.sh` |
| 7 | Qdrant VM | `vm.sh` | `vm-delete.sh` |
| 8 | GPU VM (vLLM) | `vm-gpu.sh` | `vm-gpu-delete.sh` |
| 9 | Container Apps Env | `container-app-env.sh` | `container-app-env-delete.sh` |
| 10 | Backend App | `container-app-backend.sh` | `container-app-backend-delete.sh` |
| 11 | Frontend App | `container-app-frontend.sh` | `container-app-frontend-delete.sh` |
| 12 | RBAC Roles | `identity-roles.sh` | `identity-roles-delete.sh` |

## Key Decisions

- **Azure CLI over Bicep/Terraform** — lower barrier for workshop attendees
- **vLLM on GPU VM** — NVIDIA A10 (24GB VRAM), OpenAI-compatible API
- **NVIDIA driver via VM extension** — `Microsoft.HpcCompute/NvidiaGpuDriverLinux`
- **Document Intelligence disconnected container** — runs on the Qdrant VM, license from commitment tier resource
- **Managed identity everywhere** — no API keys in scripts; RBAC roles
- **Qdrant on VM** — workshop simplicity; production would use managed vector DB
- **Container Apps** — auto-scaling, scale-to-zero for frontend & backend

## Security

- No hard-coded secrets — Key Vault references or environment variables
- Managed identity for service-to-service auth
- Qdrant and vLLM restricted to VNet traffic via NSG rules
- SSH access only for VM management
