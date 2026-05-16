---
layout: default
title: "4. Qdrant VM & Doc Intelligence"
nav_order: 6
---

# Module 4 — Qdrant VM & Document Intelligence
{: .no_toc }

Deep-dive into the vector database and cloud-based document processing.
{: .fs-6 .fw-300 }

<details open markdown="block">
  <summary>Table of contents</summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

## 4.1 Connect to the VM

```bash
# Get the VM's public IP
VM_IP=$(az vm show -g project-lab-dev -n chatbot-dev-vm \
  --show-details --query publicIps -o tsv)

# SSH in
ssh azureuser@$VM_IP
```

---

## 4.2 Qdrant Vector Database

### Verify Qdrant is running

```bash
docker ps --filter name=qdrant
```

Expected output:
```
CONTAINER ID   IMAGE            STATUS          PORTS
abc123         qdrant/qdrant    Up 2 hours      0.0.0.0:6333->6333, 0.0.0.0:6334->6334
```

### Health check

```bash
curl -s http://localhost:6333/healthz
# Expected: {"title":"qdrant - vectorass engine","version":"..."}
```

### Check collections

```bash
curl -s http://localhost:6333/collections | python3 -m json.tool
```

### Data storage

Qdrant data is persisted at `/data/qdrant`:

```bash
ls -la /data/qdrant/
```

### Configuration

| Setting | Value |
|---|---|
| REST API | `http://localhost:6333` |
| gRPC | `localhost:6334` |
| Storage | `/data/qdrant` (bind mount) |
| Auth | `QDRANT__SERVICE__API_KEY` environment variable |
| Restart | `unless-stopped` |

{: .important }
> Qdrant is protected by an API key stored in Key Vault. The embedding pipeline retrieves it via managed identity.

---

## 4.3 Document Intelligence (Cloud Service)

### How it works

Document Intelligence runs as an **Azure managed cloud service** (S0 SKU) in `southeastasia`. Documents are sent to the cloud endpoint via HTTPS, authenticated with managed identity.

```
PDF/Image → Doc Intelligence (cloud API) → Structured text/tables → Embedding pipeline
```

### Verify the service

```bash
# Get the endpoint from Key Vault
DOC_INTEL_ENDPOINT=$(az keyvault secret show \
  --vault-name chatbot-RAG-AI-Infra-kv \
  --name doc-intel-endpoint \
  --query value -o tsv)

# Test with a health check
curl -s "${DOC_INTEL_ENDPOINT}formrecognizer/documentModels?api-version=2023-07-31" \
  -H "Authorization: Bearer $(az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv)"
```

### Configuration

| Setting | Value |
|---|---|
| SKU | S0 |
| Region | `southeastasia` |
| Auth | Managed identity (`Cognitive Services User` RBAC role) |
| Endpoint | Stored in Key Vault as `doc-intel-endpoint` |

{: .important }
> The VM’s managed identity has `Cognitive Services User` role assigned, allowing the ingestion pipeline to call the cloud API without API keys.

### Re-ranker model

The cross-encoder model `ms-marco-MiniLM-L-12-v2` is loaded in-process during query time (not during ingestion):

```bash
python3 -c "from sentence_transformers import CrossEncoder; m = CrossEncoder('cross-encoder/ms-marco-MiniLM-L-12-v2'); print('Re-ranker loaded OK')"
```

---

## 4.5 Monitoring

### Docker container logs

```bash
# Qdrant logs
docker logs qdrant --tail 50
```

### Disk usage

```bash
df -h /data
du -sh /data/qdrant
```

### Memory & CPU

```bash
# System overview
free -h
top -bn1 | head -15

# Per-container
docker stats --no-stream
```

---

## 4.6 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Qdrant container not starting | Port conflict or disk full | `docker logs qdrant` + check `/data` space |
| Doc Intel returns 401 | Managed identity missing RBAC role | Assign `Cognitive Services User` role |
| Doc Intel timeout | Network or throttling issue | Check endpoint connectivity and S0 quota |
| Embedding pipeline timeout | AI Foundry throttling | Check TPM quota; add retry logic |
| Cannot reach Qdrant from backend | NSG blocking | Verify VNet peering or NSG rules |

[← Deploy Infrastructure]({{ site.baseurl }}{% link modules/03-deploy-infrastructure.md %}){: .btn .mr-2 }
[Next: GPU VM & vLLM →]({{ site.baseurl }}{% link modules/05-gpu-vllm.md %}){: .btn .btn-primary }
