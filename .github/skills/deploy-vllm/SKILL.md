---
name: deploy-vllm
description: "Deploy vLLM with Qwen3.5-9B on an Azure GPU VM (Standard_NV36ads_A10_v5). Use when: setting up LLM serving, deploying vLLM, provisioning GPU VM for inference, downloading Qwen model."
---

# Deploy vLLM with Qwen3.5-9B

Deploys vLLM serving Qwen3.5-9B on a GPU VM with NVIDIA A10 (24GB VRAM).

## Prerequisites
- GPU VM (`Standard_NV36ads_A10_v5`) already provisioned via `infra/modules/vm-gpu.sh`
- SSH access to the VM
- Managed identity assigned with `AcrPull` role (if using ACR)

## Steps

### 1. Verify GPU availability
```bash
az vm list-skus --location indonesiacentral --size Standard_NV36ads_A10_v5 \
  --query "[].{Name:name, Restrictions:restrictions}" --output table
```

### 2. Install NVIDIA drivers + Docker on the VM
```bash
# SSH into the GPU VM
ssh azureuser@<VM_IP>

# Install NVIDIA driver (Ubuntu 22.04)
sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r)
sudo apt-get install -y nvidia-driver-535

# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L "https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list" | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verify GPU
nvidia-smi
```

### 3. Download Qwen3.5-9B and run vLLM
Before downloading, verify the latest model version:
- Use `mcp_huggingface_h_hub_repo_search` with author `Qwen`, query `Qwen3.5 9B`
- Confirm model ID: `Qwen/Qwen3.5-9B`

```bash
# Run vLLM with Qwen3.5-9B (OpenAI-compatible API)
docker run -d --gpus all \
  --name vllm-qwen \
  -p 8000:8000 \
  -v /data/models:/root/.cache/huggingface \
  --restart unless-stopped \
  vllm/vllm-openai:latest \
  --model Qwen/Qwen3.5-9B \
  --host 0.0.0.0 \
  --port 8000 \
  --max-model-len 8192 \
  --gpu-memory-utilization 0.9
```

### 4. Verify the endpoint
```bash
curl http://localhost:8000/v1/models
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "Qwen/Qwen3.5-9B", "messages": [{"role": "user", "content": "Hello"}]}'
```

### 5. Secure the endpoint
- Restrict access via NSG: allow only VNet traffic on port 8000
- Optionally front with NGINX + TLS for HTTPS

## Notes
- `--max-model-len 8192` limits context to save VRAM for higher concurrency
- `--gpu-memory-utilization 0.9` uses 90% of GPU memory (~21.6 GB of 24 GB)
- Model weights cached at `/data/models` on a managed disk for persistence
- Qwen3.5-9B supports image-text-to-text (multimodal)
