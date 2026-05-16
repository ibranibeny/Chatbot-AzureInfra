---
layout: home
title: Home
nav_order: 1
description: "Build a production-ready RAG chatbot on Azure using vLLM, Qdrant, and Azure CLI"
permalink: /
---

# RAG Chatbot on Azure — Workshop
{: .fs-9 }

Build a **Retrieval-Augmented Generation (RAG) chatbot** powered by open-source LLM on Azure GPU VMs, with vector search, document intelligence, and fully automated infrastructure.
{: .fs-6 .fw-300 }

[Get Started]({{ site.baseurl }}{% link modules/01-prerequisites.md %}){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View Architecture]({{ site.baseurl }}{% link modules/02-architecture.md %}){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## What You'll Build

A complete RAG chatbot system that:

- **Ingests documents** — PDF, images, Word files parsed by Document Intelligence (cloud API)
- **Generates embeddings** — Azure AI Foundry (`text-embedding-3-small`, 1536 dimensions)
- **Stores vectors** — Qdrant vector database on a dedicated VM
- **Re-ranks results** — Cross-encoder model for improved relevance
- **Generates answers** — vLLM serving Qwen3.5-9B on NVIDIA A10 GPU
- **Serves users** — Streamlit frontend + FastAPI backend on Container Apps

## Architecture at a Glance

| Component | Technology | Azure Resource |
|---|---|---|
| 🖥️ Frontend | Streamlit | Container Apps (scale-to-zero) |
| ⚙️ Backend | FastAPI | Container Apps (scale-to-zero) |
| 🤖 LLM | vLLM + Qwen3.5-9B | GPU VM — `Standard_NV36ads_A10_v5` |
| 🗄️ Vector DB | Qdrant | VM — `Standard_D8s_v5` |
| 📄 Doc Processing | Document Intelligence | Cloud service (S0, `southeastasia`) |
| 🔗 Embeddings | `text-embedding-3-small` | Azure AI Foundry |
| 🔄 Re-ranking | `ms-marco-MiniLM-L-12-v2` | Local on VM |

## Workshop Modules

| # | Module | Duration | Description |
|---|---|---|---|
| 1 | [Prerequisites]({{ site.baseurl }}{% link modules/01-prerequisites.md %}) | 15 min | Set up your environment |
| 2 | [Architecture]({{ site.baseurl }}{% link modules/02-architecture.md %}) | 10 min | Understand the system design |
| 3 | [Deploy Infrastructure]({{ site.baseurl }}{% link modules/03-deploy-infrastructure.md %}) | 30 min | Provision all Azure resources |
| 4 | [Qdrant VM & Doc Intelligence]({{ site.baseurl }}{% link modules/04-qdrant-doc-intelligence.md %}) | 20 min | Deep-dive into vector DB & document parsing |
| 5 | [GPU VM & vLLM]({{ site.baseurl }}{% link modules/05-gpu-vllm.md %}) | 20 min | Set up LLM serving |
| 6 | [Document Ingestion]({{ site.baseurl }}{% link modules/06-ingestion.md %}) | 20 min | Ingest documents into the pipeline |
| 7 | [Backend & Frontend]({{ site.baseurl }}{% link modules/07-backend-frontend.md %}) | 25 min | Build and deploy the application |
| 8 | [Testing & Troubleshooting]({{ site.baseurl }}{% link modules/08-testing.md %}) | 15 min | Validate and debug |
| 9 | [Cleanup]({{ site.baseurl }}{% link modules/09-cleanup.md %}) | 5 min | Destroy resources |

**Total estimated time: ~2.5 hours**
{: .fs-5 .fw-300 }

## Key Design Decisions

- **Azure CLI over Bicep/Terraform** — lower barrier for workshop attendees
- **Open-source LLM (Qwen3.5-9B)** — no API key dependency, full control
- **vLLM** — OpenAI-compatible API, efficient GPU utilization
- **Document Intelligence cloud** — Azure managed service, authenticated via managed identity
- **Managed identity everywhere** — zero secrets in scripts

---

{: .note }
> This workshop targets the **`indonesiacentral`** region. GPU availability (`Standard_NV36ads_A10_v5`) should be verified before starting.
