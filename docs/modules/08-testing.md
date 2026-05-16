---
layout: default
title: "8. Testing & Troubleshooting"
nav_order: 10
---

# Module 8 — Testing & Troubleshooting
{: .no_toc }

Validate the end-to-end pipeline and resolve common issues.
{: .fs-6 .fw-300 }

<details open markdown="block">
  <summary>Table of contents</summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

## 8.1 End-to-End Validation Checklist

Run through each component to verify the full pipeline:

### 1. Qdrant — Vector database

```bash
ssh azureuser@$VM_IP

# Container running?
docker ps --filter name=qdrant

# API healthy?
curl -s http://localhost:6333/healthz

# Has data?
curl -s http://localhost:6333/collections/documents \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"Points: {d['result']['points_count']}\")"
```

### 2. Document Intelligence — Disconnected container

```bash
# Container running?
docker ps --filter name=doc-intel

# API responding?
curl -s http://localhost:5050/ | head -5
```

### 3. vLLM — LLM serving

```bash
ssh azureuser@$GPU_IP

# GPU visible?
nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv

# vLLM running?
systemctl is-active vllm.service

# Model loaded?
curl -s http://localhost:8000/v1/models | python3 -m json.tool

# Generate text?
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen3.5-9B","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}' \
  | python3 -m json.tool
```

### 4. Backend — FastAPI

```bash
BACKEND_FQDN=$(az containerapp show -g project-lab-dev -n chatbot-dev-backend \
  --query properties.configuration.ingress.fqdn -o tsv)

# Health check
curl -s https://$BACKEND_FQDN/health

# Upload a PDF document
curl -s -X POST https://$BACKEND_FQDN/upload \
  -F "file=@my-document.pdf"

# List indexed documents
curl -s https://$BACKEND_FQDN/documents | python3 -m json.tool

# Chat endpoint (ask about the uploaded document)
curl -s -X POST https://$BACKEND_FQDN/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Summarize the key points"}' | python3 -m json.tool
```

### 5. Frontend — Streamlit

```bash
FRONTEND_FQDN=$(az containerapp show -g project-lab-dev -n chatbot-dev-frontend \
  --query properties.configuration.ingress.fqdn -o tsv)

echo "Open in browser: https://$FRONTEND_FQDN"
```

---

## 8.2 Common Issues

### GPU VM

| Symptom | Diagnosis | Fix |
|---|---|---|
| `nvidia-smi` not found | Driver extension still installing | `az vm extension list -g project-lab-dev --vm-name chatbot-dev-gpu -o table` — wait for Succeeded |
| vLLM OOM | Model exceeds available VRAM | Reduce `--max-model-len 4096` or `--gpu-memory-utilization 0.85` |
| vLLM slow first response | Model loading into GPU memory | Normal — wait ~2 min after restart |
| vLLM container crash loop | CUDA version mismatch | Check `docker logs vllm-qwen`; may need driver update |

### Qdrant VM

| Symptom | Diagnosis | Fix |
|---|---|---|
| Qdrant unreachable from backend | NSG blocking | Verify `AllowQdrantFromVNet` rule exists |
| Doc Intel returns 401/403 | License expired | Re-run license download (see Module 4) |
| Doc Intel container exits | Insufficient RAM | Check `docker logs doc-intel`; need ≥16 GB |
| Embedding errors | AI Foundry throttled | Check TPM usage; add retry with backoff |

### Container Apps

| Symptom | Diagnosis | Fix |
|---|---|---|
| App stuck in "Provisioning" | Image pull failure | Check ACR login + AcrPull role assignment |
| 502 Bad Gateway | App crashing on startup | `az containerapp logs show -g project-lab-dev -n <name> --type console` |
| Cold start delays | Scale-to-zero active | Set `--min-replicas 1` for production |
| Can't reach VNet resources | VNet integration missing | Verify Container Apps env is in `apps-subnet` |

---

## 8.3 Useful Diagnostic Commands

```bash
# List all resources in the resource group
az resource list -g project-lab-dev -o table

# Check VM power states
az vm list -g project-lab-dev -d --query "[].{Name:name,State:powerState}" -o table

# Check all role assignments
az role assignment list -g project-lab-dev -o table

# Container App revisions
az containerapp revision list -g project-lab-dev -n chatbot-dev-backend -o table

# Key Vault secrets (names only)
az keyvault secret list --vault-name chatbot-dev-kv --query "[].name" -o tsv
```

---

## 8.4 Performance Testing

### Quick load test with curl

```bash
# Sequential requests
for i in $(seq 1 10); do
  time curl -s -X POST https://$BACKEND_FQDN/chat \
    -H "Content-Type: application/json" \
    -d "{\"message\":\"Test question $i\"}" > /dev/null
done
```

### Expected latencies

| Component | Expected Latency |
|---|---|
| Embedding generation | 50–100 ms |
| Qdrant similarity search | 5–20 ms |
| Re-ranking (3-5 candidates) | 50–100 ms |
| vLLM generation (200 tokens) | 2–5 seconds |
| **Total end-to-end** | **3–6 seconds** |

{: .tip }
> vLLM latency depends heavily on `max_tokens`. For faster responses, reduce the max tokens or use streaming.

[← Backend & Frontend]({{ site.baseurl }}{% link modules/07-backend-frontend.md %}){: .btn .mr-2 }
[Next: Cleanup →]({{ site.baseurl }}{% link modules/09-cleanup.md %}){: .btn .btn-primary }
