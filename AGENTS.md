# Chatbot-AzureInfra — Agent Instructions

## Project Overview

A **RAG (Retrieval-Augmented Generation) chatbot** workshop/demo that provisions Azure infrastructure using Azure CLI scripts.

### Architecture

| Component | Technology | Azure Service / SKU |
|---|---|---|
| Frontend | Streamlit (Python) | Azure Container Apps |
| Backend (RAG API) | Python (FastAPI + LangChain) | Azure Container Apps |
| RAG Framework | LangChain (`langchain`, `langchain-openai`, `langchain-qdrant`) | — |
| LLM Serving | vLLM + Qwen3.5-9B | GPU VM — `Standard_NV36ads_A10_v5` (A10, 24GB VRAM) |
| Vector Database | Qdrant (Docker) | VM — `Standard_D8s_v5` |
| Embeddings (text) | `text-embedding-3-small` | Azure AI Foundry (managed identity) |
| Embeddings (image) | Azure AI Vision or `text-embedding-3-large` | Azure AI Foundry |
| Re-ranking | `cross-encoder/ms-marco-MiniLM-L-12-v2` | Local on VM |
| Document Processing | Azure Document Intelligence (cloud) | Azure Cognitive Services S0 (`southeastasia`) |
| IaC | Azure CLI (`az`) scripts | — |
| Region | — | `indonesiacentral` |

### Data Flow

1. Documents ingested via **Document Intelligence** (cloud API in `southeastasia`) → chunked with **LangChain text splitters** → embedded via **Azure AI Foundry** (`AzureOpenAIEmbeddings`) → stored in **Qdrant** (`langchain-qdrant`)
2. User query → **Streamlit** frontend → **FastAPI** backend → **LangChain RAG chain** (embedding query → Qdrant retrieval → context + prompt → **vLLM** via `ChatOpenAI`) → response

## Project Structure

```
├── AGENTS.md                 # This file
├── infra/                    # Azure CLI provisioning scripts
│   ├── deploy.sh             # Main deployment orchestrator
│   ├── modules/              # Per-resource scripts (vm, container-app, app-service, etc.)
│   └── params/               # Environment parameter files
├── backend/                  # FastAPI RAG service (Container Apps)
│   ├── app/
│   │   ├── main.py           # FastAPI entrypoint
│   │   ├── rag/
│   │   │   └── chain.py      # LangChain RAG chain (retriever + LLM)
│   │   └── models/
│   │       └── schemas.py    # Pydantic request/response models
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/                 # Streamlit chat UI (App Service)
│   ├── app.py                # Streamlit entrypoint
│   └── requirements.txt
├── ingestion/                # Document ingestion pipeline
│   ├── ingest.py             # Orchestrates doc-intel → embed → qdrant
│   └── requirements.txt
└── docs/                     # Workshop instructions / slides
```

## Conventions

### Python
- Python 3.11+
- Use `requirements.txt` per deployable component (no monorepo single lock)
- FastAPI for the backend API; Streamlit for frontend
- **LangChain** for RAG pipeline: `langchain`, `langchain-openai`, `langchain-qdrant`
- Pydantic v2 for data validation

### Azure CLI (`az`) IaC
- All infrastructure provisioned via `az` CLI commands in shell scripts
- Scripts should be **idempotent** — safe to re-run
- Use environment variables or parameter files for configuration (resource group, location, SKU)
- Prefer **managed identity** over connection strings or keys where possible
- Always set `--output none` or `--output json` explicitly

### Security
- Never hard-code secrets — use Azure Key Vault references or environment variables
- Use managed identity for service-to-service auth (Foundry)
- Document Intelligence runs as a cloud service in `southeastasia` — authenticated via managed identity (Cognitive Services User role)
- Qdrant on VM should be on a private VNet; access via private endpoint or NSG rules

### Testing
- Backend: `pytest` with `httpx.AsyncClient` for FastAPI integration tests
- Ingestion: unit tests for chunking/embedding logic

## Build & Run

```bash
# Backend (local)
cd backend && pip install -r requirements.txt && uvicorn app.main:app --reload

# Frontend (local)
cd frontend && pip install -r requirements.txt && streamlit run app.py

# Deploy infrastructure
cd infra && bash deploy.sh

# Run ingestion
cd ingestion && pip install -r requirements.txt && python ingest.py
```

## Key Decisions

- **Region**: `indonesiacentral` — always check GPU SKU availability before provisioning
- **vLLM on GPU VM** (`Standard_NV36ads_A10_v5`) — serves Qwen3.5-9B with NVIDIA A10 (24GB VRAM); OpenAI-compatible API at `/v1/chat/completions`
- **Qwen3.5-9B** — latest ~9B model from Qwen (Apache 2.0, multimodal image-text-to-text, 8.3M+ downloads)
- **Qdrant on VM** (`Standard_D8s_v5`) — workshop simplicity; production would use Qdrant Cloud or Azure AI Search
- **Document Intelligence cloud** — Azure managed service in `southeastasia` (S0 SKU); accessed via managed identity, endpoint stored in Key Vault
- **Azure Container Apps** for frontend + backend — auto-scaling, scale-to-zero
- **Streamlit** for frontend — rapid prototyping for workshop; production would use React/Next.js
- **Azure CLI over Bicep/Terraform** — lower barrier for workshop attendees
- **Managed identity everywhere** — no API keys in scripts; use RBAC roles

## Agent Customizations

| File | Purpose |
|---|---|
| [.github/agents/azure-cli-infra.agent.md](.github/agents/azure-cli-infra.agent.md) | Azure infra provisioning agent with GPU, region, and identity logic |
| [.github/instructions/azure-cli-infra.instructions.md](.github/instructions/azure-cli-infra.instructions.md) | IaC conventions for `infra/**` scripts (idempotency, naming, Qdrant, GPU checks) |
| [.github/skills/deploy-vllm/SKILL.md](.github/skills/deploy-vllm/SKILL.md) | Skill: deploy vLLM + Qwen3.5-9B on GPU VM |
| [.github/skills/setup-qdrant-vm/SKILL.md](.github/skills/setup-qdrant-vm/SKILL.md) | Skill: set up VM with Qdrant, embedding pipeline, re-ranking |
