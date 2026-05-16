---
layout: default
title: "4. Qdrant VM & Doc Intelligence"
nav_order: 6
---

# Module 4 — Qdrant VM & Document Intelligence
{: .no_toc }

Deep-dive into the vector database and document processing setup on the multi-purpose VM.
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

## 4.3 Document Intelligence (Disconnected Container)

### How it works

Document Intelligence runs as a **disconnected Docker container** — after an initial license download, it operates fully offline. No data leaves the VM during document processing.

```
PDF/Image → Doc Intelligence (localhost:5050) → Structured text/tables → Embedding pipeline
```

### Verify the container

```bash
docker ps --filter name=doc-intel
```

Expected output:
```
CONTAINER ID   IMAGE                                       STATUS          PORTS
def456         mcr.microsoft.com/.../layout-3.0:latest     Up 1 hour       0.0.0.0:5050->5050
```

### Test document parsing

```bash
# Test with a sample request
curl -s -X POST "http://localhost:5050/formrecognizer/documentModels/prebuilt-layout:analyze?api-version=2023-07-31" \
  -H "Content-Type: application/pdf" \
  --data-binary @/path/to/sample.pdf | python3 -m json.tool
```

### License management

The license file is stored at `/data/doc-intel/license/`:

```bash
ls -la /data/doc-intel/license/
```

{: .warning }
> The license has an **expiration date**. To renew, re-run `doc-intelligence.sh` or manually run the license download step:
> ```bash
> docker run --rm -v /data/doc-intel/license:/license \
>   mcr.microsoft.com/azure-cognitive-services/form-recognizer/layout-3.0:latest \
>   eula=accept billing="$ENDPOINT" apikey="$KEY" \
>   DownloadLicense=True Mounts:License=/license
> ```

### Container configuration

| Setting | Value |
|---|---|
| Image | `mcr.microsoft.com/azure-cognitive-services/form-recognizer/layout-3.0:latest` |
| Port | `5050` (localhost only) |
| License | `/data/doc-intel/license` |
| Output logs | `/data/doc-intel/output` |
| Mode | Disconnected (offline) |
| Restart | `unless-stopped` |

---

## 4.4 Embedding Pipeline

The Python-based embedding pipeline runs on this VM and connects all the pieces:

```bash
# Check the virtual environment
source /opt/ingestion/venv/bin/activate
pip list | grep -E "qdrant|openai|sentence"
```

### Pipeline flow

1. Read document from source (local or blob storage)
2. Send to Doc Intelligence (`localhost:5050`) for text extraction
3. Chunk extracted text (512 tokens, 50 token overlap)
4. Generate embeddings via Azure AI Foundry (`text-embedding-3-small`)
5. Upsert vectors into Qdrant (`localhost:6333`)

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

# Doc Intelligence logs
docker logs doc-intel --tail 50
```

### Disk usage

```bash
df -h /data
du -sh /data/qdrant /data/doc-intel
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
| Doc Intel returns 401 | License expired | Re-run license download |
| Doc Intel container exits | Insufficient memory | VM needs ≥16 GB RAM for Doc Intel |
| Embedding pipeline timeout | AI Foundry throttling | Check TPM quota; add retry logic |
| Cannot reach Qdrant from backend | NSG blocking | Verify VNet peering or NSG rules |

[← Deploy Infrastructure]({{ site.baseurl }}{% link modules/03-deploy-infrastructure.md %}){: .btn .mr-2 }
[Next: GPU VM & vLLM →]({{ site.baseurl }}{% link modules/05-gpu-vllm.md %}){: .btn .btn-primary }
