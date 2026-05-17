---
layout: default
title: "5. GPU VM & vLLM"
nav_order: 7
---

# Module 5 — GPU VM & vLLM
{: .no_toc }

Set up the NVIDIA A10 GPU VM with vLLM serving Qwen3.5-9B as an OpenAI-compatible API.
{: .fs-6 .fw-300 }

<details open markdown="block">
  <summary>Table of contents</summary>
  {: .text-delta }
- TOC
{:toc}
</details>

---

## 5.1 Connect to the GPU VM

```bash
GPU_IP=$(az vm show -g project-lab-dev -n chatbot-dev-gpu \
  --show-details --query publicIps -o tsv)

ssh azureuser@$GPU_IP
```

---

## 5.2 Verify NVIDIA Driver

The NVIDIA driver is installed via Azure VM Extension (`Microsoft.HpcCompute/NvidiaGpuDriverLinux` v1.6):

```bash
nvidia-smi
```

Expected output:
```
+-------------------------------------------+
| NVIDIA-SMI 535.x     Driver Version: 535.x |
| CUDA Version: 12.x                         |
|-------------------------------------------+
| GPU  Name        Persistence-M| Bus-Id   |
|   0  NVIDIA A10       On      | 00000001 |
|             24576MiB /  24576MiB           |
+-------------------------------------------+
```

{: .warning }
> If `nvidia-smi` fails, the driver extension may still be installing. Check extension status:
> ```bash
> az vm extension list -g project-lab-dev --vm-name chatbot-dev-gpu -o table
> ```

---

## 5.3 vLLM Service

vLLM runs as a systemd service using Docker:

### Check service status

```bash
systemctl status vllm.service
```

### View logs

```bash
journalctl -u vllm.service --tail 50 --no-pager

# Or Docker logs directly
docker logs vllm-qwen --tail 50
```

### Service configuration

| Setting | Value |
|---|---|
| Container | `vllm/vllm-openai:latest` |
| Model | `Qwen/Qwen3.5-9B` |
| Port | `8000` |
| Max model length | `4096` tokens |
| GPU memory utilization | `0.85` (85% of 24 GB) |
| Thinking mode | Disabled (`--override-generation-config`) |
| Eager mode | `--enforce-eager` |
| API format | OpenAI-compatible |

### Docker run command

```bash
docker run -d \
  --name vllm \
  --gpus all \
  --shm-size=8g \
  -p 8000:8000 \
  vllm/vllm-openai:latest \
  --model Qwen/Qwen3.5-9B \
  --host 0.0.0.0 \
  --port 8000 \
  --max-model-len 4096 \
  --gpu-memory-utilization 0.85 \
  --enforce-eager \
  --override-generation-config '{"enable_thinking": false}'
```

{: .important }
> The `--override-generation-config '{"enable_thinking": false}'` flag disables Qwen3.5-9B's
> chain-of-thought "thinking" mode at the server level. Without this, the model generates
> internal reasoning tokens before the actual answer, resulting in 40-80s response times
> instead of 8-12s.

### Test the API

```bash
curl -s http://localhost:8000/v1/models | python3 -m json.tool
```

Generate a test completion:

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3.5-9B",
    "messages": [
      {"role": "user", "content": "What is RAG in AI?"}
    ],
    "max_tokens": 200,
    "temperature": 0.7
  }' | python3 -m json.tool
```

---

## 5.4 Model Details

### Qwen3.5-9B

| Property | Value |
|---|---|
| Parameters | ~9 billion |
| Architecture | Transformer (decoder-only) |
| License | Apache 2.0 |
| Context window | 32K tokens (limited to 8192 for memory) |
| VRAM usage | ~18 GB (FP16) |
| Capabilities | Text generation, instruction following |

### Why Qwen3.5-9B?

- **Open-source** (Apache 2.0) — no API keys, no usage limits
- **Fits on A10** — 18 GB model on 24 GB VRAM with room for KV cache
- **Strong multilingual** — good performance in Indonesian and English
- **Active community** — 8M+ downloads on Hugging Face

---

## 5.5 Performance Tuning

### GPU memory

```bash
# Check GPU memory allocation
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

### Adjust vLLM settings

If you need to change model parameters, edit the systemd service:

```bash
sudo systemctl edit vllm.service --full
# Modify ExecStart with new parameters
sudo systemctl daemon-reload
sudo systemctl restart vllm.service
```

Key parameters:
- `--max-model-len` — reduce if OOM (e.g., `4096`)
- `--gpu-memory-utilization` — reduce to `0.85` if OOM
- `--tensor-parallel-size` — for multi-GPU setups

---

## 5.6 Testing from Backend Subnet

From the Qdrant VM (same VNet), verify the GPU VM is reachable:

```bash
# From the Qdrant VM
curl -s http://chatbot-dev-gpu:8000/v1/models
# or use private IP
curl -s http://10.0.2.4:8000/v1/models
```

---

## 5.7 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `nvidia-smi` not found | Driver extension still installing | Wait 5-10 min, check extension status |
| vLLM OOM error | Model too large | Reduce `--max-model-len` or `--gpu-memory-utilization` |
| vLLM container not starting | NVIDIA runtime missing | `sudo apt install nvidia-container-toolkit` |
| Slow first response | Model loading into GPU | Wait ~2 min after service start |
| Port 8000 unreachable from VNet | NSG misconfigured | Check `gpu-nsg` rules |

[← Qdrant VM & Doc Intelligence]({{ site.baseurl }}{% link modules/04-qdrant-doc-intelligence.md %}){: .btn .mr-2 }
[Next: Document Ingestion →]({{ site.baseurl }}{% link modules/06-ingestion.md %}){: .btn .btn-primary }
