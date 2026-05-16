---
layout: default
title: "7. Backend & Frontend"
nav_order: 9
---

# Module 7 — Backend & Frontend
{: .no_toc }

Build, containerize, and deploy the FastAPI backend and Streamlit frontend to Azure Container Apps.
{: .fs-6 .fw-300 }

<details open markdown="block">
  <summary>Table of contents</summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

## 7.1 Backend — FastAPI RAG Service

### Project structure

```
backend/
├── app/
│   ├── main.py           # FastAPI entrypoint (/chat, /upload, /documents, /health)
│   ├── rag/
│   │   ├── chain.py      # LangChain RAG chain (embeddings, retriever, LLM)
│   │   └── ingest.py     # PDF parsing, chunking, embedding → Qdrant
│   └── models/
│       └── schemas.py    # Pydantic request/response models
├── Dockerfile
└── requirements.txt
```

### Run locally (for development)

```bash
cd backend
pip install -r requirements.txt

# Set environment variables
export QDRANT_URL="http://<VM_PUBLIC_IP>:6333"
export QDRANT_COLLECTION="documents"
export VLLM_BASE_URL="http://<GPU_PUBLIC_IP>:8000/v1"
export VLLM_MODEL="Qwen/Qwen3.5-9B"
export AZURE_AI_ENDPOINT="https://<AI_FOUNDRY>.openai.azure.com/"
export EMBEDDING_DEPLOYMENT="text-embedding-3-small"

uvicorn app.main:app --reload --port 8000
```

### API endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/chat` | Send a message, get RAG response |
| `POST` | `/upload` | Upload a PDF, parse → chunk → embed → store in Qdrant |
| `GET`  | `/documents` | List indexed documents |
| `GET`  | `/health` | Health check |
| `GET`  | `/docs` | Swagger UI (auto-generated) |

### Test the API

```bash
# Health check
curl https://$BACKEND_URL/health

# Upload a PDF
curl -X POST https://$BACKEND_URL/upload \
  -F "file=@my-document.pdf"

# List indexed documents
curl https://$BACKEND_URL/documents

# Chat (asks about uploaded documents)
curl -X POST https://$BACKEND_URL/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Summarize the key findings"}'
```

---

## 7.2 Frontend — Streamlit Chat UI

The Streamlit frontend provides:
- **Sidebar**: PDF file uploader + list of indexed documents
- **Main area**: Chat interface with the RAG chatbot

### Project structure

```
frontend/
├── app.py                # Streamlit entrypoint (sidebar upload + chat)
└── requirements.txt
```

### Run locally

```bash
cd frontend
pip install -r requirements.txt

export BACKEND_URL="http://localhost:8000"
streamlit run app.py --server.port 8501
```

### Upload workflow

1. Open the sidebar (☰ icon)
2. Click **Browse files** to select a PDF
3. Click **Upload & Index** to send to backend
4. Wait for confirmation (shows pages + chunks processed)
5. Ask questions about the uploaded document in chat

---

## 7.3 Build & Push Container Images

### Login to ACR

```bash
az acr login --name chatbotdevacr
```

### Build and push backend

```bash
cd backend
docker build -t chatbotdevacr.azurecr.io/chatbot-backend:latest .
docker push chatbotdevacr.azurecr.io/chatbot-backend:latest
```

### Build and push frontend

```bash
cd frontend
docker build -t chatbotdevacr.azurecr.io/chatbot-frontend:latest .
docker push chatbotdevacr.azurecr.io/chatbot-frontend:latest
```

### Verify images in ACR

```bash
az acr repository list --name chatbotdevacr --output table
az acr repository show-tags --name chatbotdevacr --repository chatbot-backend --output table
```

---

## 7.4 Deploy to Container Apps

After pushing images, update the Container Apps:

```bash
cd infra
bash modules/container-app-backend.sh
bash modules/container-app-frontend.sh
```

### Verify deployment

```bash
# Backend status
az containerapp show -g project-lab-dev -n chatbot-dev-backend \
  --query "{status:properties.runningStatus, fqdn:properties.configuration.ingress.fqdn}" \
  -o table

# Frontend status
az containerapp show -g project-lab-dev -n chatbot-dev-frontend \
  --query "{status:properties.runningStatus, fqdn:properties.configuration.ingress.fqdn}" \
  -o table
```

### Get the frontend URL

```bash
FRONTEND_URL=$(az containerapp show -g project-lab-dev -n chatbot-dev-frontend \
  --query properties.configuration.ingress.fqdn -o tsv)
echo "Open: https://$FRONTEND_URL"
```

---

## 7.5 Environment Variables

### Backend Container App

| Variable | Value | Source |
|---|---|---|
| `QDRANT_URL` | `http://<VM_PUBLIC_IP>:6333` | VM public IP |
| `QDRANT_COLLECTION` | `documents` | Environment |
| `VLLM_BASE_URL` | `http://<GPU_PUBLIC_IP>:8000/v1` | GPU VM public IP |
| `VLLM_MODEL` | `Qwen/Qwen3.5-9B` | Environment |
| `AZURE_AI_ENDPOINT` | `https://<AI_FOUNDRY>.openai.azure.com/` | AI Foundry |
| `EMBEDDING_DEPLOYMENT` | `text-embedding-3-small` | Environment |

### Frontend Container App

| Variable | Value |
|---|---|
| `BACKEND_URL` | Backend Container App internal FQDN |

---

## 7.6 Scaling Configuration

Both apps use consumption-based scaling:

| Setting | Backend | Frontend |
|---|---|---|
| Min replicas | 0 | 0 |
| Max replicas | 3 | 3 |
| Scale trigger | HTTP concurrent requests | HTTP concurrent requests |
| CPU | 1 core | 0.5 core |
| Memory | 2 Gi | 1 Gi |

{: .tip }
> Set min replicas to `1` in production to avoid cold-start latency:
> ```bash
> az containerapp update -g project-lab-dev -n chatbot-dev-backend \
>   --min-replicas 1
> ```

---

## 7.7 View Logs

```bash
# Backend console logs
az containerapp logs show -g project-lab-dev -n chatbot-dev-backend --type console --tail 50

# Backend system logs
az containerapp logs show -g project-lab-dev -n chatbot-dev-backend --type system --tail 20
```

[← Document Ingestion]({{ site.baseurl }}{% link modules/06-ingestion.md %}){: .btn .mr-2 }
[Next: Testing & Troubleshooting →]({{ site.baseurl }}{% link modules/08-testing.md %}){: .btn .btn-primary }
