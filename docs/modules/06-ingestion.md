---
layout: default
title: "6. Document Ingestion"
nav_order: 8
---

# Module 6 — Document Ingestion
{: .no_toc }

Ingest documents through the full pipeline: parse → chunk → embed → store in Qdrant.
{: .fs-6 .fw-300 }

<details open markdown="block">
  <summary>Table of contents</summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

## 6.1 Pipeline Overview

```
Documents (PDF, DOCX, images)
    │
    ▼
Document Intelligence (localhost:5050)
    │  Extract text, tables, layout
    ▼
Chunking (Python)
    │  Split into ~512 token chunks with 50 token overlap
    ▼
Azure AI Foundry (text-embedding-3-small)
    │  Generate 1536-dimension vectors
    ▼
Qdrant (localhost:6333)
    │  Store vectors + metadata
    ▼
Ready for RAG queries
```

---

## 6.2 Prepare the Ingestion Environment

SSH into the Qdrant VM and activate the environment:

```bash
VM_IP=$(az vm show -g project-lab-dev -n chatbot-dev-vm \
  --show-details --query publicIps -o tsv)
ssh azureuser@$VM_IP

# Activate the ingestion environment
source /opt/ingestion/venv/bin/activate
```

---

## 6.3 Prepare Sample Documents

Create a sample documents directory:

```bash
mkdir -p ~/sample-docs

# Copy your PDF files here, or create a test document
cat > ~/sample-docs/test.txt << 'EOF'
Azure Container Apps is a serverless container service that enables
you to run microservices and containerized applications on a serverless
platform. It supports scale-to-zero, built-in authentication, and
Dapr integration for microservices communication.
EOF
```

---

## 6.4 Run the Ingestion Pipeline

```bash
cd /opt/ingestion
python ingest.py --source ~/sample-docs/
```

### What happens during ingestion

1. **Discovery** — Scans `--source` directory for supported files (PDF, DOCX, PNG, JPG, TXT)
2. **Parsing** — Sends each file to Document Intelligence at `localhost:5050`
3. **Chunking** — Splits extracted text into chunks (configurable size/overlap)
4. **Embedding** — Calls Azure AI Foundry to generate vectors
5. **Storage** — Upserts vectors with metadata into Qdrant

### Monitor progress

```bash
# Watch Qdrant for new vectors
watch -n 5 'curl -s http://localhost:6333/collections/documents | python3 -m json.tool | grep points_count'
```

---

## 6.5 Verify Ingestion

### Check collection stats

```bash
curl -s http://localhost:6333/collections/documents | python3 -m json.tool
```

Expected output includes:
```json
{
  "result": {
    "status": "green",
    "vectors_count": 42,
    "points_count": 42
  }
}
```

### Test a similarity search

```bash
# Generate a query vector (via AI Foundry) and search
python3 << 'PYEOF'
from qdrant_client import QdrantClient
from openai import AzureOpenAI
from azure.identity import DefaultAzureCredential

# Connect to Qdrant
qd = QdrantClient(url="http://localhost:6333")

# Get embedding for query
credential = DefaultAzureCredential()
token = credential.get_token("https://cognitiveservices.azure.com/.default")
ai = AzureOpenAI(
    azure_endpoint="https://chatbot-dev-ai.openai.azure.com/",
    api_key=token.token,
    api_version="2024-02-01"
)

response = ai.embeddings.create(
    model="text-embedding-3-small",
    input="What is Azure Container Apps?"
)
query_vector = response.data[0].embedding

# Search
results = qd.search(
    collection_name="documents",
    query_vector=query_vector,
    limit=3
)

for r in results:
    print(f"Score: {r.score:.4f}")
    print(f"Text: {r.payload.get('text', '')[:200]}")
    print("---")
PYEOF
```

---

## 6.6 Chunking Strategy

| Parameter | Default | Description |
|---|---|---|
| Chunk size | 512 tokens | Maximum tokens per chunk |
| Chunk overlap | 50 tokens | Overlap between consecutive chunks |
| Separator | `\n\n` then `\n` then `. ` | Text splitting hierarchy |

{: .tip }
> For technical documents with code blocks, consider increasing chunk size to 1024 tokens to avoid splitting code snippets.

---

## 6.7 Batch Processing Tips

For large document sets:

```bash
# Process with rate limiting (avoid AI Foundry throttling)
python ingest.py --source ~/large-docs/ --batch-size 10 --delay 1.0

# Resume after interruption (skips already-processed files)
python ingest.py --source ~/large-docs/ --skip-existing
```

{: .note }
> The default AI Foundry deployment has 120K TPM (tokens per minute). For large batches, consider increasing the TPM quota in Azure Portal.

---

## 6.8 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Connection refused localhost:5050` | Doc Intel container not running | `docker start doc-intel` |
| `429 Too Many Requests` | AI Foundry rate limit | Add delays or increase TPM quota |
| Empty extraction results | Unsupported file format | Check Doc Intel supported formats |
| Qdrant upsert fails | Collection not created | Run collection creation script |
| Slow ingestion | Large files or images | Pre-process to reduce file size |

[← GPU VM & vLLM]({{ site.baseurl }}{% link modules/05-gpu-vllm.md %}){: .btn .mr-2 }
[Next: Backend & Frontend →]({{ site.baseurl }}{% link modules/07-backend-frontend.md %}){: .btn .btn-primary }
